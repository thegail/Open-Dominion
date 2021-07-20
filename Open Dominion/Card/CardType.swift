//
//  CardType.swift
//  Open Dominion
//
//  Created by Teddy Gaillard on 7/9/21.
//

import Foundation

enum CardType {
	case action
	case treasure
	case victory((Player) -> Int)
}
