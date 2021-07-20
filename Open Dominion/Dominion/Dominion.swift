//
//  Dominion.swift
//  Open Dominion
//
//  Created by Teddy Gaillard on 7/10/21.
//

import Foundation

fileprivate func doCellar(player: Player, level: UInt, then callback: @escaping (UInt) -> Void) {
	player.getInput(prompt: "\u{1B}[34mDiscard a card or /done", mustMatch: { candidate in
		if candidate == "/done" {
			return true
		}
		return player.hand.contains {
			return $0.name.lowercased() == candidate.lowercased()
		}
	}) { cardName in
		if cardName == "/done" {
			callback(level)
		} else {
			player.game.log("\u{1B}[34m\(player.name) discards \((player.hand.first { return $0.name.lowercased() == cardName.lowercased() }?.name)!)\u{1B}[0m")
			player.discard(at: player.hand.firstIndex {
				return $0.name.lowercased() == cardName.lowercased()
			}!)
			doCellar(player: player, level: level + 1, then: callback)
		}
	}
}

fileprivate func doChapel(player: Player, level: UInt, then callback: @escaping () -> Void) {
	if level >= 4 {
		callback()
	} else {
		player.getInput(prompt: "\u{1B}[34mTrash a card or /done", mustMatch: { candidate in
			if candidate == "/done" {
				return true
			}
			return player.hand.contains {
				return $0.name.lowercased() == candidate.lowercased()
			}
		}) { cardName in
			if cardName == "/done" {
				callback()
			} else {
				player.game.log("\u{1B}[34m\(player.name) trashes \((player.hand.first { return $0.name.lowercased() == cardName.lowercased() }?.name)!)\u{1B}[0m")
				player.hand.remove(at: player.hand.firstIndex { $0.name.lowercased() == cardName.lowercased() }!)
				doChapel(player: player, level: level + 1, then: callback)
			}
		}
	}
}

fileprivate func doPoacher(player: Player, level: UInt, then callback: @escaping () -> Void) {
	if (level >= player.game.marketplace.filter { return $0.count == 0 }.count || player.hand.count == 0) {
		callback()
	} else {
		player.getInput(prompt: "Discard card", mustMatch: { candidate in
			return player.hand.contains { return $0.name.lowercased() == candidate.lowercased() }
		}) { cardName in
			player.game.log("\u{1B}[34m\(player.name) discards \((player.hand.first { return $0.name.lowercased() == cardName.lowercased() }?.name)!)\u{1B}[0m")
			player.discard(at: player.hand.firstIndex { return $0.name.lowercased() == cardName.lowercased() }!)
			doPoacher(player: player, level: level + 1, then: callback)
		}
	}
}

fileprivate func doLibrary(player: Player, actions: Array<Card> = [], then callback: @escaping () -> Void) {
	if player.hand.count >= 7 {
		player.discard.append(contentsOf: actions)
		callback()
	} else {
		var newActions = actions
		player.draw()
		switch player.hand.last!.type {
		case .action:
			player.confirm(
				prompt: "\u{1B}[34mSkip action \(player.hand.last!.name)?\u{1B}[0m",
				then: {
					newActions.append(player.hand.last!)
					player.hand.removeLast()
				},
				always: {
					doLibrary(player: player, actions: actions, then: callback)
				}
			)
			
		default:
			doLibrary(player: player, actions: actions, then: callback)
		}
	}
}

fileprivate func doMilitiaEffect(player: Player, then callback: @escaping () -> Void) {
	if player.hand.count <= 3 {
		callback()
	} else {
		player.getInput(prompt: "Discard", mustMatch: { candidate in
			return player.hand.contains { $0.name.lowercased() == candidate.lowercased() }
		}) { cardName in
			player.game.log("\(player.name) discards \(player.hand.first { return $0.name.lowercased() == cardName.lowercased() }!.name)")
			player.discard(at: player.hand.firstIndex { return $0.name.lowercased() == cardName.lowercased() }!)
			doMilitiaEffect(player: player, then: callback)
		}
	}
}

enum Dominion {
	
	static let copper = Card(
		name: "Copper",
		type: .treasure,
		cost: 0,
		action: { player, callback in
			player.coins += 1
			callback()
		},
		description: "\u{1B}[33m+1 coin\u{1B}[0m"
	)
	
	static let silver = Card(
		name: "Silver",
		type: .treasure,
		cost: 3,
		action: { player, callback in
			player.coins += 2
			callback()
		},
		description: "\u{1B}[33m+2 coins\u{1B}[0m"
	)
	
	static let gold = Card(
		name: "Gold",
		type: .treasure,
		cost: 6,
		action: { player, callback in
			player.coins += 3
			callback()
		},
		description: "\u{1B}[33m+3 coins\u{1B}[0m"
	)
	
	static let estate = Card(
		name: "Estate",
		type: .victory({ _ in return 1 }),
		cost: 2,
		action: { _, callback in callback() },
		description: "\u{1B}[32m1 vicory point\u{1B}[0m"
	)
	
	static let duchy = Card(
		name: "Duchy",
		type: .victory({ _ in return 3 }),
		cost: 5,
		action: { _, callback in callback() },
		description: "\u{1B}[32m3 vicory points\u{1B}[0m"
	)
	
	static let province = Card(
		name: "Province",
		type: .victory({ _ in return 6 }),
		cost: 8,
		action: { _, callback in callback() },
		description: "\u{1B}[32m6 vicory points\u{1B}[0m"
	)
	
	static let curse = Card(
		name: "Curse",
		type: .victory({ _ in return -1 }),
		cost: 0,
		action: { _, callback in callback() },
		description: "\u{1B}[32m-1 vicory point\u{1B}[0m"
	)
	
	static let cellar = Card(
		name: "Cellar",
		type: .action,
		cost: 2,
		action: { player, callback in
			player.actions += 1
			doCellar(player: player, level: 0) { number in
				player.draw(number)
				callback()
			}
		},
		description: "\u{1B}[36m+1 Action\u{1B}[0m. Discard any number of cards, then draw that many"
	)
	
	static let chapel = Card(
		name: "Chapel",
		type: .action,
		cost: 2,
		action: { player, callback in
			doChapel(player: player, level: 0, then: callback)
		},
		description: "Trash up to 4 cards from your hand."
	)
	
	static let moat = Card(
		name: "Moat",
		type: .action,
		cost: 2,
		action: { player, callback in
			player.draw(2)
			callback()
		},
		description: "+2 Cards. When another player plays an Attack card, you may first reveal this from your hand, to be unaffected by it.",
		blocksAttacks: true
	)
	
	static let chancellor = Card(
		name: "Chancellor",
		type: .action,
		cost: 3,
		action: { player, callback in
			player.coins += 2
			player.confirm(
				prompt: "\u{1B}[34mWould you like to put your deck into your discard pile?\u{1B}[0m",
				then: {
					player.game.log("\u{1B}[34m\(player.name) discards deck\u{1B}[0m")
					player.discard.append(contentsOf: player.deck)
					player.deck = []
				},
				always: callback
			)
		},
		description: "\u{1B}[33m+2 coins\u{1B}[0m. You may immediately put your deck into your discard pile."
	)
	
	static let harbinger = Card(
		name: "Harbinger",
		type: .action,
		cost: 3,
		action: { player, callback in
			player.draw()
			player.actions += 2
			// finish
			callback()
		},
		description: "+1 card, \u{1B}[36m1 action\u{1B}[0m. Look through your discard pile. You may put a card from it onto your deck."
	)
	
	static let vassal = Card(
		name: "Vassal",
		type: .action,
		cost: 3,
		action: { player, callback in
			player.coins += 2
			player.draw()
			player.discard(at: player.hand.count - 1)
			player.game.log("\u{1B}[34m\(player.name) discards \(player.discard.last!.name)\u{1B}[0m")
			switch player.discard.last?.type {
			case .action:
				player.confirm(
					prompt: "\u{1B}[34mWould you like to play \(player.discard.last!.name)?\u{1B}[0m",
					then: {
						player.game.log("\u{1B}[34m\(player.name) plays \(player.discard.last!.name)\u{1B}[0m")
						player.discard.last!.action(player, callback)
					},
					not: callback
				)
			default:
				callback()
			}
		},
		description: "\u{1B}[33m+2 coins\u{1B}[0m. Discard the top card of your deck. If it's an Action card, you may play it."
	)
	
	static let village = Card(
		name: "Village",
		type: .action,
		cost: 3,
		action: { player, callback in
			player.draw()
			player.actions += 2
			callback()
		},
		description: "+1 card, \u{1B}[36m+2 actions\u{1B}[0m."
	)
	
	static let woodcutter = Card(
		name: "Woodcutter",
		type: .action,
		cost: 3,
		action: { player, callback in
			player.buys += 1
			player.coins += 2
			callback()
		},
		description: "\u{1B}[35m+1 buy\u{1B}[0m, \u{1B}[33m+2 coins\u{1B}[0m."
	)
	
	static let workshop = Card(
		name: "Workshop",
		type: .action,
		cost: 3,
		action: { player, callback in
			player.gainCard(prompt: "\u{1B}[34mGain a card\u{1B}[0m", matching: { return $0.cost <= 3 }, then: callback)
		},
		description: "Gain a card costing up to \u{1B}[33m4 coins\u{1B}[0m."
	)
	
	static let bureaucrat = Card(
		name: "Bureaucrat",
		type: .action,
		cost: 4,
		action: { player, callback in
			if let silverIndex = (player.game.marketplace.firstIndex { return $0.card.name == "Silver" }) {
				if player.game.marketplace[silverIndex].count > 0 {
					player.game.marketplace[silverIndex].count -= 1
					player.deck = [player.game.marketplace[silverIndex].card] + player.deck
				}
			} else {
				player.deck = [Dominion.silver] + player.deck
			}
			var remainingCount = player.game.players.count
			for otherPlayer in player.game.players where otherPlayer !== player {
				otherPlayer.attack(blocked: {
					remainingCount -= 1
					if remainingCount <= 0 {
						callback()
					}
				}) {
					if (otherPlayer.hand.contains { candidate in
						switch candidate.type {
						case .victory(_):
							return true
						default:
							return false
						}
					}) {
						otherPlayer.getInput(prompt: "Put victory card onto deck", mustMatch: { candidate in
							guard let card = (otherPlayer.hand.first { return $0.name.lowercased() == candidate.lowercased() }) else {
								return false
							}
							switch card.type {
							case .victory(_):
								return true
							default:
								return false
							}
						}) { cardName in
							let cardIndex = otherPlayer.hand.firstIndex { return $0.name.lowercased() == cardName.lowercased() }!
							otherPlayer.deck = [otherPlayer.hand[cardIndex]] + otherPlayer.deck
							otherPlayer.hand.remove(at: cardIndex)
							remainingCount -= 1
							if remainingCount <= 0 {
								callback()
							}
						}
					} else {
						otherPlayer.game.log(otherPlayer.hand.reduce(into: "\(otherPlayer.name) has hand ", { $0 += $1.name + "" }))
						remainingCount -= 1
						if remainingCount <= 0 {
							callback()
						}
					}
				}
			}
		},
		description: "Gain a Silver onto your deck. Each other player reveals a Victory card from their hand and puts it onto their deck (or reveals a hand with no Victory cards)."
	)
	
	static let feast = Card(
		name: "Feast",
		type: .action,
		cost: 4,
		action: { player, callback in
			player.game.table.remove(at: player.game.table.firstIndex { return $0.name == "Feast" }!)
			player.gainCard(prompt: "\u{1B}[34mGain a card\u{1B}[0m", matching: { return $0.cost <= 5 }, then: callback)
		},
		description: "Trash this card. Gain a card costing up to \u{1B}[33m5 coins\u{1B}[0m."
	)
	
	static let gardens = Card(
		name: "Gardens",
		type: .victory({ player in
			return Int(floor(Double(player.deck.count + player.discard.count + player.hand.count) / 10))
		}),
		cost: 4,
		action: { _, callback in callback() },
		description: "Worth \u{1B}[32m1 victory point\u{1B}[0m per 10 cards you have (rounded down)."
	)
	
	static let militia = Card(
		name: "Militia",
		type: .action,
		cost: 4,
		action: { player, callback in
			player.coins += 2
			var remaining = player.game.players.count - 1
			for otherPlayer in player.game.players where otherPlayer !== player {
				otherPlayer.attack(blocked: {
					remaining -= 1
					if remaining <= 0 {
						callback()
					}
				}) {
					doMilitiaEffect(player: otherPlayer) {
						remaining -= 1
						if remaining <= 0 {
							callback()
						}
					}
				}
			}
		},
		description: "\u{1B}[33m+2 coins\u{1B}[0m. Each other player discards down to 3 cards in hand."
	)
	
	static let moneylender = Card(
		name: "Moneylender",
		type: .action,
		cost: 4,
		action: { player, callback in
			if (player.hand.contains { return $0.name == "Copper" }) {
				player.confirm(
					prompt: "\u{1B}[34mWould you like to trash a Copper from your hand?\u{1B}[0m",
					then: {
						player.game.log("\u{1B}[34m\(player.name) trashes a Copper\u{1B}[0m")
						player.hand.remove(at: player.hand.firstIndex { return $0.name == "Copper" }!)
					},
					always: {
						callback()
					}
				)
			} else {
				callback()
			}
		},
		description: "You may trash a Copper from your hand for \u{1B}[33m+3 coins\u{1B}[0m."
	)
	
	static let poacher = Card(
		name: "Poacher",
		type: .action,
		cost: 4,
		action: { player, callback in
			player.draw()
			player.actions += 1
			player.coins += 1
			doPoacher(player: player, level: 0, then: callback)
		},
		description: "+1 card, \u{1B}[36m+1 action\u{1B}[0m, \u{1B}[33m+1 coin\u{1B}[0m. Discard a card per empty Supply pile."
	)
	
	static let remodel = Card(
		name: "Remodel",
		type: .action,
		cost: 4,
		action: { player, callback in
			player.getInput(prompt: "Trash a card from your hand", mustMatch: { candidate in
				return player.hand.contains { return $0.name.lowercased() == candidate.lowercased() }
			}) { cardName in
				let trashedCard = player.hand.first { return $0.name.lowercased() == cardName.lowercased() }!
				player.game.log("\u{1B}[34m\(player.name) trashes \(trashedCard.name)\u{1B}[0m")
				player.hand.remove(at: player.hand.firstIndex { return $0.name.lowercased() == cardName.lowercased() }!)
				player.gainCard(prompt: "\u{1B}[34mGain a card costing up to \u{1B}[33m\(trashedCard.cost + 2) coins\u{1B}[0m", matching: { return $0.cost <= trashedCard.cost + 2 }) {
					callback()
				}
			}
		},
		description: "Trash a card from your hand. Gain a card costing up to \u{1B}[33m2 coins\u{1B}[0m more than it."
	)
	
	static let smithy = Card(
		name: "Smithy",
		type: .action,
		cost: 4,
		action: { player, callback in
			player.draw(3)
			callback()
		},
		description: "+3 cards"
	)
	
	static let spy = Card(
		name: "Spy",
		type: .action,
		cost: 4,
		action: { player, callback in
			// finish
		},
		description: "+1 card, \u{1B}[36m+1 action\u{1B}[0m. Each player (including you) reveals the top card of their deck and either discards it or puts it back, your choice."
	)
	
	static let theif = Card(
		name: "Theif",
		type: .action,
		cost: 4,
		action: { player, callback in
			// finish
		},
		description: "Each other player reveals the top 2 cards of their deck. If they revealed any Treasure cards, they trash one of them that you choose. You may gain any or all of these trashed cards. They discard the other revealed cards."
	)
	
	static let throneRoom = Card(
		name: "ThroneRoom",
		type: .action,
		cost: 4,
		action: { player, callback in
			player.getInput(prompt: "\u{1B}[34mPlay an action from your hand twice", mustMatch: { candidate in
				return player.hand.contains { $0.name.lowercased() == candidate.lowercased() }
			}) { cardName in
				let cardIndex = player.hand.firstIndex { $0.name.lowercased() == cardName.lowercased() }!
				let card = player.hand[cardIndex]
				player.playCard(at: cardIndex) {
					card.action(player, callback)
				}
			}
		},
		description: "You may play an Action card from your hand twice."
	)
	
	static let bandit = Card(
		name: "Bandit",
		type: .action,
		cost: 5,
		action: { player, callback in
			if let goldIndex = (player.game.marketplace.firstIndex { return $0.card.name == "Gold" }) {
				if player.game.marketplace[goldIndex].count > 0 {
					player.game.marketplace[goldIndex].count -= 1
					player.discard.append(player.game.marketplace[goldIndex].card)
				}
			} else {
				player.discard.append(Dominion.gold)
			}
			for otherPlayer in player.game.players where otherPlayer !== player {
				var remaining = player.game.players.count
				otherPlayer.attack(blocked: {
					remaining -= 1
					if remaining <= 0 {
						callback()
					}
				}) {
					var topCards: Array<Card> = []
					for _ in 1...2 {
						if otherPlayer.deck.isEmpty {
							guard !otherPlayer.discard.isEmpty else {
								break
							}
							otherPlayer.deck = otherPlayer.discard.shuffled()
							otherPlayer.discard = []
						}
						topCards.append(otherPlayer.deck.first!)
						otherPlayer.deck.removeFirst()
					}
					if (topCards.contains { candidate in
						switch candidate.type {
						case .treasure:
							return candidate.name != "Copper"
						default:
							return false
						}
					}) {
						otherPlayer.getInput(prompt: "Trash non-copper treasure", mustMatch: { candidate in
							guard let card = (topCards.first { return $0.name.lowercased() == candidate.lowercased() }) else {
								return false
							}
							switch card.type {
							case .treasure:
								return card.name != "Copper"
							default:
								return false
							}
						}) { cardName in
							let cardIndex = topCards.firstIndex { return $0.name.lowercased() == cardName.lowercased() }!
							topCards.remove(at: cardIndex)
							otherPlayer.discard.append(contentsOf: topCards)
							remaining -= 1
							if remaining <= 0 {
								callback()
							}
						}
					} else {
						otherPlayer.discard.append(contentsOf: topCards)
						remaining -= 1
						if remaining <= 0 {
							callback()
						}
					}
				}
			}
		},
		description: "Gain a Gold. Each other player reveals the top 2 cards of their deck, trashes a revealed Treasure other than Copper, and discards the rest."
	)
	
	static let councilRoom = Card(
		name: "CouncilRoom",
		type: .action,
		cost: 5,
		action: { player, callback in
			player.draw(3)
			player.buys += 1
			for otherPlayer in player.game.players where otherPlayer !== player {
				otherPlayer.draw()
			}
			callback()
		},
		description: "+4 cards, \u{1B}[35m+1 buy\u{1B}[0m. Each other player draws a card."
	)
	
	static let festival = Card(
		name: "Festival",
		type: .action,
		cost: 5,
		action: { player, callback in
			player.actions += 2
			player.buys += 1
			player.coins += 2
			callback()
		},
		description: "\u{1B}[36m+2 actions\u{1B}[0m, \u{1B}[35m+1 buy\u{1B}[0m, \u{1B}[33m+2 coins\u{1B}[0m."
	)
	
	static let laboratory = Card(
		name: "Laboratory",
		type: .action,
		cost: 5,
		action: { player, callback in
			player.draw(2)
			player.actions += 1
			callback()
		},
		description: "+2 cards, \u{1B}[36m+1 action\u{1B}[0m"
	)
	
	static let library = Card(
		name: "Library",
		type: .action,
		cost: 5,
		action: { player, callback in
			doLibrary(player: player, then: callback)
		},
		description: "Draw until you have 7 cards in hand, skipping any Action cards you choose to; set those aside, discarding them afterwards."
	)
	
	static let market = Card(
		name: "Market",
		type: .action,
		cost: 5,
		action: { player, callback in
			player.draw()
			player.actions += 1
			player.buys += 1
			player.coins += 1
			callback()
		},
		description: "+1 card, \u{1B}[36m+1 action\u{1B}[0m, \u{1B}[35m+1 buy\u{1B}[0m, \u{1B}[33m+1 coin\u{1B}[0m."
	)
	
	static let mine = Card(
		name: "Mine",
		type: .action,
		cost: 5,
		action: { player, callback in
			player.getInput(prompt: "\u{1B}[34mTrash a treasure or /done\u{1B}[0m", mustMatch: { candidate in
				if candidate == "/done" {
					return true
				}
				guard let card = (player.hand.first { $0.name.lowercased() == candidate.lowercased() }) else {
					return false
				}
				switch card.type {
				case .treasure:
					return true
				default:
					return false
				}
			}) { cardName in
				let card = player.hand.first { return $0.name.lowercased() == cardName.lowercased() }!
				player.game.log("\u{1B}[34m\(player.name) trashes \(card.name)\u{1B}[0m")
				player.hand.remove(at: player.hand.firstIndex { return $0.name.lowercased() == cardName.lowercased() }!)
				player.gainCard(prompt: "\u{1B}[34mGain a treasure costing up to \u{1B}[33m\(card.cost + 3) coins\u{1B}[0m", matching: { candidate in
					switch candidate.type {
					case .treasure:
						return candidate.cost <= card.cost + 3
					default:
						return false
					}
				}, toHand: true, then: callback)
			}
		},
		description: "You may trash a Treasure card from your hand. Gain a Treasure card to your hand costing up to \u{1B}[33m3 coins\u{1B}[0m more than it."
	)
	
	static let sentry = Card(
		name: "Sentry",
		type: .action,
		cost: 5,
		action: { player, callback in
			player.draw()
			player.actions += 1
			if player.deck.count < 2 {
				player.deck.append(contentsOf: player.discard.shuffled())
				player.discard = []
			}
			if player.deck.count < 2 {
				// finish
			} else {
				
			}
		},
		description: "+1 card, \u{1B}[36m+1 action\u{1B}[0m. Look at the top 2 cards of your deck. Trash and/or discard any number of them. Put the rest back on top in any order."
	)
	
	static let witch = Card(
		name: "Witch",
		type: .action,
		cost: 5,
		action: { player, callback in
			for otherPlayer in player.game.players where otherPlayer !== player {
				otherPlayer.attack(blocked: callback) {
					if let curseIndex = (otherPlayer.game.marketplace.firstIndex { return $0.card.name == "Curse" }) {
						if otherPlayer.game.marketplace[curseIndex].count > 0 {
							otherPlayer.game.marketplace[curseIndex].count -= 1
							otherPlayer.discard.append(otherPlayer.game.marketplace[curseIndex].card)
						}
					} else {
						otherPlayer.discard.append(Dominion.curse)
					}
					callback()
				}
			}
		},
		description: "+2 cards. Each other player gains a Curse."
	)
	
	static let adventurer = Card(
		name: "Adventurer",
		type: .action,
		cost: 6,
		action: { player, callback in
			var treasures: Array<Card> = []
			var others: Array<Card> = []
			while treasures.count < 2 {
				if player.deck.isEmpty {
					guard !player.discard.isEmpty else {
						player.hand.append(contentsOf: treasures)
						player.discard.append(contentsOf: others)
						callback()
						return
					}
					player.deck = player.discard.shuffled()
					player.discard = []
				}
				switch player.deck.first!.type {
				case .treasure:
					treasures.append(player.deck.first!)
				default:
					others.append(player.deck.first!)
				}
				player.game.log("\u{1B}[34m\(player.name) reveals \(player.deck.first!.name)\u{1B}[0m")
				player.deck.removeFirst()
			}
			player.hand.append(contentsOf: treasures)
			player.discard.append(contentsOf: others)
		},
		description: "Reveal cards from your deck until you reveal 2 Treasure cards. Put those Treasure cards into your hand and discard the other revealed cards."
	)
	
	static let artisan = Card(
		name: "Artisan",
		type: .action,
		cost: 6,
		action: { player, callback in
			player.gainCard(prompt: "Gain a card to your hand", matching: { return $0.cost <= 5 }, toHand: true) {
				player.getInput(prompt: "Put a card on top of deck", mustMatch: { candidate in
					return player.hand.contains { return $0.name.lowercased() == candidate.lowercased() }
				}) { cardName in
					player.deck = [player.hand.first { return $0.name.lowercased() == cardName.lowercased() }!] + player.deck
					player.hand.remove(at: player.hand.firstIndex { return $0.name.lowercased() == cardName.lowercased() }!)
					callback()
				}
			}
		},
		description: "Gain a card to your hand costing up to \u{1B}[33m5 coins\u{1B}[0m. Put a card from your hand onto your deck."
	)
}
