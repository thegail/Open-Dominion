//
//  Prosperity.swift
//  Open Dominion
//
//  Created by Teddy Gaillard on 7/19/21.
//

import Foundation

enum Prosperity {
	
	static let loan = Card(
		name: "Loan",
		type: .treasure,
		cost: 3,
		action: { player, callback in
			var cards: Array<Card> = []
			var lastIsTreasure = false
			while !lastIsTreasure {
				if player.deck.isEmpty {
					guard !player.discard.isEmpty else {
						player.discard.append(contentsOf: cards)
						callback()
						return
					}
					player.deck = player.discard.shuffled()
					player.discard = []
				}
				cards.append(player.deck.first!)
				player.deck.removeFirst()
				switch cards.last!.type {
				case .treasure:
					lastIsTreasure = false
				default:
					break
				}
				player.game.log("\u{1B}[34m\(player.name) reveals \(cards.last!.name)\u{1B}[0m")
			}
			player.getInput(prompt: "\u{1B}[34mDiscard \(cards.last!.name) or trash?\u{1B}[0m", mustMatch: { candidate in
				return ["discard", "trash", "d", "t"].contains(candidate.lowercased())
			}) { choice in
				switch choice.lowercased() {
				case "discard", "d":
					player.game.log("\u{1B}[34m\(player.name) discards \(cards.last!.name)\u{1B}[0m")
					player.discard.append(cards.last!)
					cards.removeLast()
					player.discard.append(contentsOf: cards)
				case "trash", "t":
					player.game.log("\u{1B}[34m\(player.name) trashes \(cards.last!.name)\u{1B}[0m")
					cards.removeLast()
					player.discard.append(contentsOf: cards)
				default:
					fatalError()
				}
				callback()
			}
		},
		description: "\u{1B}[33m+1 coin\u{1B}[0m. Reveal cards from your deck until you reveal a Treasure. Discard it or trash it. Discard the other cards."
	)
	
}
