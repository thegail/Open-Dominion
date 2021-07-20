//
//  Player.swift
//  Open Dominion
//
//  Created by Teddy Gaillard on 7/9/21.
//

import Foundation
import Network

class Player {
	let name: String
	var dashboard: Dashboard {
		didSet {
			self.send(data: self.dashboard.text.data(using: .utf8) ?? Data())
		}
	}
	weak var game: Game!
	let connection: NWConnection
	var messageHandler: (Data?) -> Void
	
	var deck: Array<Card> {
		didSet {
			self.dashboard.deckCount = UInt(self.deck.count)
		}
	}
	var hand: Array<Card> {
		didSet {
			self.dashboard.hand = self.hand
		}
	}
	var discard: Array<Card> {
		didSet {
			self.dashboard.discardCount = UInt(self.discard.count)
			self.dashboard.discardTop = self.discard.last
		}
	}
	
	var coins: Int {
		didSet {
			self.dashboard.coins = UInt(self.coins)
		}
	}
	var actions: UInt {
		didSet {
			self.dashboard.actions = self.actions
		}
	}
	var buys: UInt {
		didSet {
			self.dashboard.buys = self.buys
		}
	}
	
	init(name: String, connection: NWConnection, game: Game) {
		self.name = name
		self.dashboard = Dashboard(
			width: 80,
			height: 24,
			prompt: "\u{1B}[1mChat >\u{1B}[0m ",
			log: ["Welcome, \(name)"],
			players: game.players.map { return $0.name },
			currentPlayerIndex: 0,
			deckCount: 15,
			discardCount: 0,
			hand: [],
			table: [],
			marketplace: game.marketplace,
			hasDescriptions: true,
			coins: 0,
			actions: 0,
			buys: 0
		)
		self.game = game
		self.connection = connection
		self.messageHandler = { _ in return }
		
		self.deck = game.rules.startingDeck.shuffled()
		self.hand = []
		self.discard = []
		
		self.coins = 0
		self.actions = 0
		self.buys = 0
		
		self.draw(5)
		self.send(data: self.dashboard.text.data(using: .utf8) ?? Data())
		self.setupReceive()
		self.messageHandler = self.chatHandler
	}
	
	private func chatHandler(message: Data?) {
		if var chat = String(data: message ?? Data() , encoding: .utf8) {
			if chat.last == "\n" {
				chat.removeLast()
			}
			if chat.first == "/" {
				self.game.executeCommand(chat, from: self)
			} else {
				self.game.sendChat(chat, from: self.name)
			}
		}
	}
	
	private func setupReceive() {
		self.connection.receive(minimumIncompleteLength: 1, maximumLength: 64) { data, _, _, error in
			if error != nil {
				print("Error receiving message")
			} else {
				self.messageHandler(data)
			}
			self.setupReceive()
		}
	}
	
	private func send(data: Data) {
		self.connection.send(content: data, completion: .contentProcessed({ error in
			if error != nil {
				print("Error sending message")
			}
		}))
	}
	
	func updateGameDashboard() {
		self.dashboard.players = self.game.players.map { return $0.name }
		self.dashboard.currentPlayerIndex = self.game.currentPlayerIndex
		self.dashboard.marketplace = self.game.marketplace
		self.dashboard.table = self.game.table
	}
	
	func getInput(prompt: String, mustMatch pattern: @escaping (String) -> Bool = { _ in return true }, retrying: Bool = false, completion: @escaping (String) -> Void) {
		self.dashboard.prompt = "\u{1B}[1m\(prompt) >\u{1B}[0m "
		self.messageHandler = { data in
			self.dashboard.prompt = "\u{1B}[1mChat >\u{1B}[0m "
			self.messageHandler = self.chatHandler
			var string = String(data: data ?? Data(), encoding: .utf8) ?? ""
			if string.last == "\n" {
				string.removeLast()
			}
			if pattern(string) {
				completion(string)
			} else {
				if retrying {
					self.getInput(prompt: prompt, mustMatch: pattern, retrying: true, completion: completion)
				} else {
					self.getInput(prompt: "\u{1B}[1;31m[Retry]\u{1B}[0m " + prompt, mustMatch: pattern, retrying: true, completion: completion)
				}
			}
		}
	}
	
	func confirm(prompt: String, then: @escaping () -> Void, not: @escaping () -> Void = { return }, always: @escaping () -> Void = { return }) {
		self.getInput(
			prompt: prompt,
			mustMatch: { return ["y", "n", "yes", "no"].contains($0.lowercased()) },
			completion: { response in
				switch response {
				case "y", "yes":
					then()
					always()
				case "n", "no":
					not()
					always()
				default:
					fatalError()
				}
			}
		)
	}
	
	func draw(_ number: UInt = 1) {
		guard number > 0 else {
			return
		}
		for _ in 1...number {
			if self.deck.isEmpty {
				guard !self.discard.isEmpty else {
					return
				}
				self.deck = self.discard.shuffled()
				self.discard = []
			}
			self.hand.append(self.deck.first!)
			self.deck.removeFirst()
		}
	}
	
	func playCard(at index: Int, then callback: @escaping () -> Void) {
		self.game.table.append(self.hand[index])
		let card = self.hand[index]
		self.hand.remove(at: index)
		card.action(self, callback)
	}
	
	func discard(at index: Int) {
		self.discard.append(self.hand[index])
		self.hand.remove(at: index)
	}
	
	func gainCard(prompt: String, matching condition: @escaping (Card) -> Bool, toHand: Bool = false, then callback: @escaping () -> Void) {
		self.getInput(prompt: prompt, mustMatch: { candidate in
			return self.game.marketplace.contains { return $0.card.name.lowercased() == candidate.lowercased() && $0.count > 0 && condition($0.card) }
		}) { cardName in
			let cardIndex = self.game.marketplace.firstIndex { return $0.card.name.lowercased() == cardName.lowercased() }!
			let card = self.game.marketplace[cardIndex].card
			if toHand {
				self.hand.append(card)
			} else {
				self.discard.append(card)
			}
			self.game.marketplace[cardIndex].count -= 1
			self.game.log("\u{1B}[34m\(self.name) gains \(self.game.marketplace[cardIndex].card.name)\(toHand ? " to hand" : "")\u{1B}[0m")
			callback()
		}
	}
	
	private func playAll(where condition: @escaping (Card) -> Bool, then callback: @escaping () -> Void) {
		if let indexOfTreasure = (self.hand.firstIndex { return condition($0) }) {
			self.game.log("\u{1B}[33m\(self.name) plays \(self.hand[indexOfTreasure].name)\u{1B}[0m")
			self.playCard(at: indexOfTreasure) {
				self.playAll(where: condition, then: callback)
			}
		} else {
			callback()
		}
	}
	
	private func actionStage(then callback: @escaping () -> Void) {
		if (self.hand.contains {
			switch $0.type {
			case .action:
				return true
			default:
				return false
			}
		} && self.actions > 0) {
			self.getInput(prompt: "\u{1B}[36mPlay action or /done", mustMatch: { candidate in
				if candidate == "/done" {
					return true
				} else if candidate.first == "/" {
					self.game.executeCommand(candidate, from: self)
					return false
				}
				guard let card = (self.hand.first { $0.name.lowercased() == candidate.lowercased() }) else {
					return false
				}
				switch card.type {
				case .action:
					return true
				default:
					return false
				}
			}) { cardName in
				if cardName != "/done" {
					let cardIndex = self.hand.firstIndex { return $0.name.lowercased() == cardName.lowercased() }
					self.game.log("\u{1B}[36m\(self.name) plays \(self.hand[cardIndex!].name)\u{1B}[0m")
					self.playCard(at: cardIndex!) {
						self.actions -= 1
						self.actionStage(then: callback)
					}
				} else {
					callback()
				}
			}
		} else {
			callback()
		}
	}
	
	private func treasureStage(then callback: @escaping () -> Void) {
		if (self.hand.contains {
			switch $0.type {
			case .treasure:
				return true
			default:
				return false
			}
		}) {
			self.getInput(prompt: "\u{1B}[33mPlay treasure, /done, /all, or /some", mustMatch: { candidate in
				if candidate == "/done" || candidate == "/all" || candidate == "/some" {
					return true
				} else if candidate.first == "/" {
					self.game.executeCommand(candidate, from: self)
					return false
				}
				guard let card = (self.hand.first { $0.name.lowercased() == candidate.lowercased() }) else {
					return false
				}
				switch card.type {
				case .treasure:
					return true
				default:
					return false
				}
			}) { cardName in
				if cardName == "/all" {
					self.playAll(where: { candidate in
						switch candidate.type {
						case .treasure:
							return true
						default:
							return false
						}
					}) {
						self.treasureStage(then: callback)
					}
				} else if cardName == "/some" {
					self.playAll(where: { return self.game.rules.basicTreasures.contains($0.name) }) {
						self.treasureStage(then: callback)
					}
				} else if cardName == "/done" {
					callback()
				} else {
					let cardIndex = self.hand.firstIndex { return $0.name.lowercased() == cardName.lowercased() }
					self.game.log("\u{1B}[33m\(self.name) plays \(self.hand[cardIndex!].name)\u{1B}[0m")
					self.playCard(at: cardIndex!) {
						self.treasureStage(then: callback)
					}
				}
			}
		} else {
			callback()
		}
	}
	
	private func buyStage(then callback: @escaping () -> Void) {
		if self.buys > 0 {
			self.getInput(prompt: "\u{1B}[35mBuy card or /done", mustMatch: { candidate in
				if candidate == "/done" {
					return true
				} else if candidate.first == "/" {
					self.game.executeCommand(candidate, from: self)
					return false
				}
				return self.game.marketplace.contains {
					return $0.card.name.lowercased() == candidate.lowercased() &&
						$0.count > 0 &&
						self.coins >= $0.card.cost
				}
			}) { cardName in
				if cardName != "/done" {
					let marketplaceIndex = self.game.marketplace.firstIndex {
						return $0.card.name.lowercased() == cardName.lowercased()
					}!
					self.hand.append(self.game.marketplace[marketplaceIndex].card)
					self.game.marketplace[marketplaceIndex].count -= 1
					self.buys -= 1
					self.coins -= self.game.marketplace[marketplaceIndex].card.cost
					self.game.log("\u{1B}[35m\(self.name) buys \(self.game.marketplace[marketplaceIndex].card.name)\u{1B}[0m")
					self.buyStage(then: callback)
				} else {
					callback()
				}
			}
		} else {
			callback()
		}
	}
	
	func playTurn(then callback: @escaping () -> Void) {
		self.actions = 1
		self.buys = 1
		
		self.actionStage {
			self.treasureStage {
				self.buyStage {
					self.coins = 0
					self.discard.append(contentsOf: self.game.table)
					self.discard.append(contentsOf: self.hand)
					self.game.table = []
					self.hand = []
					self.draw(5)
					callback()
				}
			}
		}
	}
	
	func attack(blocked: @escaping () -> Void, _ body: @escaping () -> Void) {
		if (self.hand.contains { return $0.blocksAttacks }) {
			self.getInput(prompt: "Choose card to block attack or /done", mustMatch: { candidate in
				if candidate == "/done" {
					return true
				}
				return self.hand.contains { return $0.name.lowercased() == candidate.lowercased() && $0.blocksAttacks }
			}) { cardName in
				if cardName == "/done" {
					body()
				} else {
					let card = self.hand.first { return $0.name.lowercased() == cardName.lowercased() && $0.blocksAttacks }!
					self.game.log("\(self.name) blocks with \(card.name)")
					blocked()
				}
			}
		} else {
			body()
		}
	}
}
