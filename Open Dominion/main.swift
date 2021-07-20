//
//  main.swift
//  Open Dominion
//
//  Created by Teddy Gaillard on 7/9/21.
//

import Foundation
import Network

let game = try Game(port: 1952, rules: .dominion, marketplace: [
	(card: Dominion.copper, count: 30),
	(card: Dominion.gold, count: 30),
	(card: Dominion.silver, count: 30),
	(card: Dominion.estate, count: 12),
	(card: Dominion.duchy, count: 10),
	(card: Dominion.province, count: 8),
	(card: Dominion.curse, count: 20),
	(card: Dominion.cellar, count: 10),
	(card: Dominion.moat, count: 10),
	(card: Dominion.village, count: 10),
	(card: Dominion.smithy, count: 10),
	(card: Dominion.militia, count: 10),
	(card: Dominion.throneRoom, count: 10),
	(card: Dominion.laboratory, count: 10),
	(card: Dominion.festival, count: 10),
	(card: Dominion.market, count: 10),
	(card: Dominion.mine, count: 10)
])

print("Listening")

DispatchQueue(label: "com.thegail.Dominion.waitThread").async {
	print("<Enter> to start", terminator: "")
	_ = readLine()
	game.start()
}

RunLoop.main.run()
