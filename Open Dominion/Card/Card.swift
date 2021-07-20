//
//  Card.swift
//  Open Dominion
//
//  Created by Teddy Gaillard on 7/19/21.
//

import Foundation

struct Card {
	let name: String
	let type: CardType
	let cost: Int
	let action: (Player, @escaping () -> Void) -> Void
	let description: String
	
	let blocksAttacks: Bool
	
	init(name: String, type: CardType, cost: Int, action: @escaping (Player, @escaping () -> Void) -> Void, description: String, blocksAttacks: Bool = false) {
		self.name = name
		self.type = type
		self.cost = cost
		self.action = action
		self.description = description
		self.blocksAttacks = blocksAttacks
	}
}
