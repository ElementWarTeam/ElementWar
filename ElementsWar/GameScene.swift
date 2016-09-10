//
//  GameScene.swift
//  ElementsWar
//
//  Created by Sidney on 9/9/16.
//  Copyright (c) 2016 Siqi. All rights reserved.
//

import SpriteKit

class GameScene: SKScene {

    let playerSprite = SKSpriteNode(imageNamed: "Player")
    let movingControllerSprite = SKSpriteNode(imageNamed: "Cannon")

    let movingControllerOriginPosition = CGPoint(x: 80, y: 80)
    var touchLocation: CGPoint?
    var playerLocation: CGPoint = CGPoint()
    var movingDirection: CGFloat = 0.0

    override func didMoveToView(view: SKView) {
        /* Setup your scene here */
//        let myLabel = SKLabelNode(fontNamed:"Chalkduster")
//        myLabel.text = "Hello, World!"
//        myLabel.fontSize = 45
//        myLabel.position = CGPoint(x:CGRectGetMidX(self.frame), y:CGRectGetMidY(self.frame))
//
//        self.addChild(myLabel)

        // set scene size to match view
        size = view.bounds.size
        backgroundColor = SKColor(red: 94.0 / 255, green: 63.0 / 255, blue: 107.0 / 255, alpha: 1)
        playerSprite.position = CGPoint(x: size.width - 50, y: 60)
        movingControllerSprite.position = movingControllerOriginPosition
        addChild(playerSprite)
        addChild(movingControllerSprite)
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        /* Called when a touch begins */

//        for touch in touches {
//            let location = touch.locationInNode(self)
//
//            let sprite = SKSpriteNode(imageNamed: "Spaceship")
//
//            sprite.xScale = 0.5
//            sprite.yScale = 0.5
//            sprite.position = location
//
//            let action = SKAction.rotateByAngle(CGFloat(M_PI), duration: 1)
//
//            sprite.runAction(SKAction.repeatActionForever(action))
//
//            self.addChild(sprite)
//        }

        if let touch = touches.first {
            let touchLocation = touch.locationInNode(self)
            if(movingControllerSprite.containsPoint(touchLocation)){
                self.touchLocation = touchLocation
            }else{
                self.touchLocation = nil
            }

        }
        super.touchesBegan(touches, withEvent: event)
    }

    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touch = touches.first, let touchLocation = self.touchLocation {
            let moveTolocation = touch.locationInNode(self)
            let hypo = hypot(moveTolocation.x - touchLocation.x - touchLocation.x, moveTolocation.y - touchLocation.y)
            let speed: CGFloat = 10
            playerSprite.position.x += speed * (moveTolocation.x - touchLocation.x) / hypo
            playerSprite.position.y += speed * (moveTolocation.y - touchLocation.y) / hypo
            movingControllerSprite.position = moveTolocation
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        movingControllerSprite.position = movingControllerOriginPosition
    }

    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
    }
}
