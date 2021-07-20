//
//  Dashboard.swift
//  Open Dominion
//
//  Created by Teddy Gaillard on 7/19/21.
//

import Foundation

struct Dashboard {
	
	var width: UInt
	var height: UInt
	
	var prompt: String
	var log: Array<String>
	
	var players: Array<String>
	var currentPlayerIndex: Int
	
	var deckCount: UInt
	var discardCount: UInt
	var discardTop: Card?
	var hand: Array<Card>
	var table: Array<Card>
	
	var marketplace: Array<(card: Card, count: UInt)>
	var hasDescriptions: Bool
	
	var coins: UInt
	var actions: UInt
	var buys: UInt
	
	var lines: Array<String> {
		return [
			self.players.enumerated().reduce(into: "Players: ") {
				$0 += (
					$1.offset == self.currentPlayerIndex ?
						"\u{1B}[1;32m\($1.element)\u{1B}[0m" :
						$1.element
				) + " "
			},
			"",
			self.marketplace.reduce(into: "\u{1B}[1mMarketplace:\u{1B}[0m\n") {
				var coloredName: String
				switch $1.card.type {
				case .action:
					coloredName = $1.card.name
				case .treasure:
					coloredName = "\u{1B}[33m\($1.card.name)\u{1B}[0m"
				case .victory(_):
					coloredName = "\u{1B}[32m\($1.card.name)\u{1B}[0m"
				}
				$0 += "\(coloredName) (\u{1B}[33m\($1.card.cost) coins\u{1B}[0m) \($1.count == 0 ? "\u{1B}[31m" : "")x\($1.count)\($1.count == 0 ? "\u{1B}[0m" : "")\(self.hasDescriptions ? " " + $1.card.description : "")\n"
			},
			"Deck: \(self.deckCount) cards",
			self.hand.reduce(into: "Hand: ") {
				var coloredName: String
				switch $1.type {
				case .action:
					coloredName = $1.name
				case .treasure:
					coloredName = "\u{1B}[33m\($1.name)\u{1B}[0m"
				case .victory(_):
					coloredName = "\u{1B}[32m\($1.name)\u{1B}[0m"
				}
				$0 += coloredName + " "
			},
			"Discard: \(self.discardCount) cards. Top: \(self.discardTop?.name ?? "none")",
			self.table.reduce(into: "Table: ") {
				var coloredName: String
				switch $1.type {
				case .action:
					coloredName = $1.name
				case .treasure:
					coloredName = "\u{1B}[33m\($1.name)\u{1B}[0m"
				case .victory(_):
					coloredName = "\u{1B}[32m\($1.name)\u{1B}[0m"
				}
				$0 += coloredName + " "
			},
			"",
			"\u{1B}[33mCoins: \(self.coins)\u{1B}[0m",
			"\u{1B}[36mActions: \(self.actions)\u{1B}[0m",
			"\u{1B}[35mBuys: \(self.buys)\u{1B}[0m",
			"",
			self.log.suffix(15).reduce(into: "\u{1B}[1mLog:\u{1B}[0m\n") {
				$0 += " \($1)\n"
			}
		]
	}
	var text: String {
		return lines.reduce(into: "\u{1B}[2J\n") { $0 += $1 + "\n" } + self.prompt
	}
}
