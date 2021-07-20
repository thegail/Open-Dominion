//
//  GameRules.swift
//  Open Dominion
//
//  Created by Teddy Gaillard on 7/9/21.
//

import Foundation

struct GameRules {
	let startingDeck: Array<Card>
	let basicTreasures: Set<String>
	let criticalCards: Set<String>
	
	static let dominion = GameRules(
		startingDeck:
			Array<Card>(repeating: Dominion.copper, count: 7) +
			Array<Card>(repeating: Dominion.estate, count: 3),
		basicTreasures: [
			"Copper",
			"Silver",
			"Gold"
		],
		criticalCards: [
			"Province"
		]
	)
}
