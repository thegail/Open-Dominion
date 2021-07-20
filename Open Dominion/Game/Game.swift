//
//  Game.swift
//  Open Dominion
//
//  Created by Teddy Gaillard on 7/19/21.
//

import Foundation
import Network

class Game {
	private(set) var players: Array<Player> {
		didSet {
			for player in self.players {
				player.updateGameDashboard()
			}
		}
	}
	let rules: GameRules
	var marketplace: Array<(card: Card, count: UInt)> {
		didSet {
			let emptyStacks = marketplace.filter { return $0.count == 0 }
			if (emptyStacks.count >= 3 || !Set(emptyStacks.map { return $0.card.name }).isDisjoint(with: self.rules.criticalCards)) {
				self.isEnding = true
			}
			for player in self.players {
				player.updateGameDashboard()
			}
		}
	}
	let listener: NWListener
	private(set) var isPlaying: Bool
	private var isEnding: Bool
	private(set) var currentPlayerIndex: Int {
		didSet {
			for player in self.players {
				player.updateGameDashboard()
			}
		}
	}
	var table: Array<Card> {
		didSet {
			for player in self.players {
				player.updateGameDashboard()
			}
		}
	}
	
	init(port: UInt16, rules: GameRules, marketplace: Array<(card: Card, count: UInt)>) throws {
		self.players = []
		self.rules = rules
		self.marketplace = marketplace
		self.table = []
		self.listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
		self.isPlaying = false
		self.isEnding = false
		self.currentPlayerIndex = 0
		self.listener.newConnectionHandler = self.onNewConnection
		self.listener.start(queue: .main)
	}
	
	private func onNewConnection(connection: NWConnection) {
		if self.isPlaying {
			connection.start(queue: .main)
			connection.send(content: "\u{1B}[1;31mGame started already\u{1B}[0m\n".data(using: .utf8), completion: .contentProcessed({ error in
				if error != nil {
					print(error!)
				}
				connection.cancel()
			}))
		} else {
			connection.start(queue: .main)
			connection.send(content: "\u{1B}[1mYour name >\u{1B}[0m ".data(using: .utf8), completion: .contentProcessed({ error in
				if error != nil {
					print(error!)
				}
			}))
			connection.receive(minimumIncompleteLength: 1, maximumLength: 64) { data, _, _, error in
				if error != nil {
					print(error!)
				} else {
					guard var playerName = String(data: data ?? Data(), encoding: .utf8) else {
						return
					}
					if playerName.last == "\n" {
						playerName.removeLast()
					}
					self.players.append(Player(name: playerName, connection: connection, game: self))
					self.log("\(playerName) has joined the game")
				}
			}
		}
	}
	
	func start() {
		self.isPlaying = true
		self.log("\u{1B}[32mThe game has started\u{1B}[0m")
		self.nextPlayer()
	}
	
	private func nextPlayer() {
		self.log("\u{1B}[32mIt is now \(self.players[self.currentPlayerIndex].name)'s turn\u{1B}[0m")
		self.players[self.currentPlayerIndex].playTurn {
			if self.isEnding {
				self.endGame()
			} else {
				if self.currentPlayerIndex == self.players.count - 1 {
					self.currentPlayerIndex = 0
				} else {
					self.currentPlayerIndex += 1
				}
				self.nextPlayer()
			}
		}
	}
	
	private func endGame() {
		var totals: Array<(name: String, score: Int)> = []
		for player in self.players {
			var total = 0
			for card in player.deck + player.discard + player.hand {
				switch card.type {
				case .victory(let victoryFunction):
					total += victoryFunction(player)
				default:
					break
				}
			}
			totals.append((name: player.name, score: total))
		}
		totals.sort { return $0.score < $1.score }
		self.log("\u{1B}[32mThe game has ended.\u{1B}[0m")
		self.log("Scores:")
		for total in totals {
			self.log("\(total.name): \u{1B}[32m\(total.score)\u{1B}[0m")
		}
		self.log("The winner is \(totals.last!.name)!")
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			for player in self.players {
				player.connection.cancel()
			}
			self.listener.cancel()
			exit(0)
		}
	}
	
	func log(_ message: String) {
		for player in self.players {
			player.dashboard.log.append(message)
		}
	}
	
	func sendChat(_ message: String, from name: String) {
		self.log("[\(name)]: \(message)")
	}
	
	func executeCommand(_ command: String, from player: Player) {
		let arguments = Array<String>(command.split(separator: " ").suffix(from: 1).map { return String($0) })
		let base = command.split(separator: " ").first ?? ""
		switch base {
		case "/desc":
			if arguments.count == 1 {
				if let card = (self.marketplace.first { candidate in
					return candidate.card.name.lowercased() == arguments[0]
				})?.card {
					player.dashboard.log.append("\u{1B}[1mDescription of \(card.name):\u{1B}[0m \(card.description)")
				} else {
					player.dashboard.log.append("\u{1B}[1;31mCard \u{1B}[3m\(arguments[0])\u{1B}[3m not found\u{1B}[0m")
				}
			} else {
				player.dashboard.log.append("\u{1B}[1;31mInvalid usage of /desc. Try \u{1B}[3m/usage desc\u{1B}[0m")
			}
		case "/dd":
			if arguments.count == 1 {
				switch arguments[0] {
				case "show":
					player.dashboard.hasDescriptions = true
				case "hide":
					player.dashboard.hasDescriptions = false
				default:
					player.dashboard.log.append("\u{1B}[1;31mInvalid usage of /dd. Try \u{1B}[3m/usage dd\u{1B}[0m")
				}
			} else {
				player.dashboard.log.append("\u{1B}[1;31mInvalid usage of /dd. Try \u{1B}[3m/usage dd\u{1B}[0m")
			}
		case "/help":
			if arguments.count == 0 {
				player.dashboard.log.append("Insert help here")
			} else {
				player.dashboard.log.append("\u{1B}[1;31mInvalid usage of /help. Try \u{1B}[3m/usage help\u{1B}[0m")
			}
		case "/usage":
			if arguments.count == 1 {
				if let usageText = usage[String(arguments[0])] {
					player.dashboard.log.append("\u{1B}[1mDescription of \(arguments[0]):\u{1B}[0m \(usageText)")
				} else {
					player.dashboard.log.append("\u{1B}[1;31mCommand \u{1B}[3m\(arguments[0])\u{1B}[3m not found\u{1B}[0m")
				}
			} else {
				player.dashboard.log.append("\u{1B}[1;31mInvalid usage of /usage. Try \u{1B}[3m/usage usage\u{1B}[0m")
			}
		default:
			player.dashboard.log.append("\u{1B}[1;31mInvalid command. Try \u{1B}[3m/help\u{1B}[0m")
		}
	}
}
