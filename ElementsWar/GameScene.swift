//
//  GameScene.swift
//  ElementsWar
//
//  Created by Sidney on 9/9/16.
//  Copyright (c) 2016 Siqi. All rights reserved.
//

import SpriteKit

class GameScene: SKScene {

    let Pi = CGFloat(M_PI)
    let PlayerMissileSpeed: CGFloat = 300

    let playerSprite: SKSpriteNode? = SKSpriteNode(imageNamed: "Player")

    let moveAnalogStick = AnalogJoystick(diameter: 110)
    let rotateAnalogStick = AnalogJoystick(diameter: 100)

    let missileShootSound = SKAction.playSoundFileNamed("Shoot.wav", waitForCompletion: false)

    var isFirePressed = false

    // Time of last update(currentTime:) call
    var lastUpdateTime = NSTimeInterval(0)

    // Seconds elapsed since last action
    var timeSinceLastAction = NSTimeInterval(0)

    // Seconds before performing next action. Choose a default value
    var timeUntilNextAction = NSTimeInterval(0.7)

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
        if let playerSprite = self.playerSprite {
            playerSprite.position = CGPoint(x: self.frame.maxX / 2, y: self.frame.maxY / 2)
            addChild(playerSprite)
        }

        // add joySticker
        moveAnalogStick.position = CGPoint(x: moveAnalogStick.radius + 15, y: moveAnalogStick.radius + 15)
        addChild(moveAnalogStick)

        rotateAnalogStick.position = CGPoint(x: self.frame.maxX - rotateAnalogStick.radius - 15, y: rotateAnalogStick.radius + 15)
        addChild(rotateAnalogStick)

        // set up joySticker
        moveAnalogStick.startHandler = { }
        moveAnalogStick.stopHandler = { }
        moveAnalogStick.trackingHandler = { [unowned self] data in

            guard let aN = self.playerSprite else { return }
            let scale: CGFloat = 0.04
            aN.position = CGPointMake(aN.position.x + (data.velocity.x * scale), aN.position.y + (data.velocity.y * scale))
        }

        rotateAnalogStick.startHandler = { [unowned self] _ in
            self.isFirePressed = true
        }
        rotateAnalogStick.trackingHandler = { [unowned self] jData in
            print("trackingHandler")
            self.playerSprite?.zRotation = jData.angular
        }

        rotateAnalogStick.stopHandler = { [unowned self] _ in
            self.isFirePressed = false
        }

    }

    func shootMissle(fromNode node: SKNode) {
        let playerMissileSprite = SKSpriteNode(imageNamed: "PlayerMissile")
        playerMissileSprite.zRotation = node.zRotation
        playerMissileSprite.position = node.position
        self.addChild(playerMissileSprite)

        let travelDistance: CGFloat = 1000
        let action = SKAction.moveTo(
            CGPointMake(
                travelDistance * cos(playerMissileSprite.zRotation + self.Pi / 2.0) + playerMissileSprite.position.x,
                travelDistance * sin(playerMissileSprite.zRotation + self.Pi / 2.0) + playerMissileSprite.position.y
            ),
            duration: 6)

        playerMissileSprite.runAction(SKAction.sequence([self.missileShootSound, action])) {
            playerMissileSprite.hidden = true
        }
    }

    override func update(currentTime: CFTimeInterval) {

        let delta = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        timeSinceLastAction += delta

        if let playerSprite = self.playerSprite
        where timeSinceLastAction >= timeUntilNextAction && isFirePressed {
            shootMissle(fromNode: playerSprite)
            timeSinceLastAction = NSTimeInterval(0)
        }

    }
}
