//
//  GameScene.swift
//  ElementsWar
//
//  Created by Sidney on 9/9/16.
//  Copyright (c) 2016 Siqi. All rights reserved.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {

    let Pi = CGFloat(M_PI)
    let PlayerMissileSpeed: CGFloat = 300

    let kElementName = "element"
    let kObstacleName = "obstacle"
    let kBulletName = "bullet"

    let kObstacleCategory: UInt32 = 0x1 << 0
    let kShipFiredBulletCategory: UInt32 = 0x1 << 1
    let kShipCategory: UInt32 = 0x1 << 2;
    let kSceneEdgeCategory: UInt32 = 0x1 << 3;
    let kInvaderFiredBulletCategory: UInt32 = 0x1 << 4;

    var playerElement: SKSpriteNode?

    let moveAnalogStick = AnalogJoystick(diameter: 100)
    let rotateAnalogStick = AnalogJoystick(diameter: 100)

    let missileShootSound = SKAction.playSoundFileNamed("Shoot.wav", waitForCompletion: false)

    var isFirePressed = false

    // Time of last update(currentTime:) call
    var lastUpdateTime = NSTimeInterval(0)

    // Seconds elapsed since last action
    var timeSinceLastAction = NSTimeInterval(0)

    // Seconds before performing next action. Choose a default value
    var timeUntilNextAction = NSTimeInterval(0.7)

    // contact
    var contactQueue = [SKPhysicsContact]()

    override func didMoveToView(view: SKView) {

        self.physicsBody?.categoryBitMask = kSceneEdgeCategory;

        self.physicsWorld.contactDelegate = self

        // set scene size to match view
        size = view.bounds.size
        backgroundColor = SKColor(red: 250.0 / 255, green: 250.0 / 255, blue: 245.0 / 255, alpha: 0.5)
        let bgImage = SKSpriteNode(imageNamed: "wallpaper.png")
        self.addChild(bgImage)
        bgImage.position = CGPointMake(self.size.width/2, self.size.height/2)
        
        self.playerElement = makeElement()

        // TODO: add player
        if let element = playerElement {
            addChild(element)
        }
        
        // Add controllers
        setupControllers()

    }

    func shootMissle(fromNode node: SKNode) {
        let playerMissileSprite = makeBullet()
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

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let location = touch.locationInNode(self)
            if !moveAnalogStick.containsPoint(location) && !rotateAnalogStick.containsPoint(location) {
                let obstacle = makeObstacle()
                obstacle.position = location
                addChild(obstacle)
            }
        }
    }

    override func update(currentTime: CFTimeInterval) {

        let delta = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        timeSinceLastAction += delta

        if let playerElement = self.playerElement
        where isFirePressed && timeSinceLastAction >= timeUntilNextAction {
            shootMissle(fromNode: playerElement)
            timeSinceLastAction = NSTimeInterval(0)
        }

        processContactsForUpdate(currentTime)

    }

    // MARK: Create basic sprite

    func setupControllers() {
        // add joySticker
        moveAnalogStick.position = CGPoint(x: moveAnalogStick.radius + 15, y: moveAnalogStick.radius + 15)
        addChild(moveAnalogStick)

        rotateAnalogStick.position = CGPoint(x: self.frame.maxX - rotateAnalogStick.radius - 15, y: rotateAnalogStick.radius + 15)
        addChild(rotateAnalogStick)

        // set up joySticker
        moveAnalogStick.stick.image = UIImage(named: "Sticker")
        moveAnalogStick.substrate.image = UIImage(named: "SubSticker")
        rotateAnalogStick.stick.image = UIImage(named: "Sticker")
        rotateAnalogStick.substrate.image = UIImage(named: "SubSticker")

        moveAnalogStick.stick.color = SKColor.clearColor()
        moveAnalogStick.substrate.color = SKColor.clearColor()
        rotateAnalogStick.stick.color = SKColor.clearColor()
        rotateAnalogStick.substrate.color = SKColor.clearColor()

        moveAnalogStick.startHandler = { }
        moveAnalogStick.stopHandler = { }
        moveAnalogStick.trackingHandler = { [unowned self] data in

            guard let aN = self.playerElement else { return }
            let scale: CGFloat = 0.04
            aN.position = CGPointMake(aN.position.x + (data.velocity.x * scale), aN.position.y + (data.velocity.y * scale))
        }

        rotateAnalogStick.startHandler = { [unowned self] _ in
            self.isFirePressed = true
        }
        rotateAnalogStick.trackingHandler = { [unowned self] jData in
            self.playerElement?.zRotation = jData.angular
        }

        rotateAnalogStick.stopHandler = { [unowned self] _ in
            self.isFirePressed = false
        }
    }

    func makeElement() -> SKSpriteNode {
        let element = SKSpriteNode(imageNamed: "FireElement")
        element.position = CGPoint(x: self.frame.maxX / 2, y: self.frame.maxY / 2)
        element.name = kElementName
        element.physicsBody?.categoryBitMask = kShipCategory
        element.physicsBody?.contactTestBitMask = 0x0
        element.physicsBody?.collisionBitMask = kSceneEdgeCategory
        return element
    }

    func makeBullet() -> SKSpriteNode {
        let bullet = SKSpriteNode(imageNamed: "FireBall")
        bullet.name = kBulletName
        bullet.physicsBody = SKPhysicsBody(rectangleOfSize: bullet.frame.size)
        bullet.physicsBody?.dynamic = true
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.categoryBitMask = kShipFiredBulletCategory
        bullet.physicsBody?.contactTestBitMask = kObstacleCategory
        bullet.physicsBody?.collisionBitMask = 0x0
        return bullet
    }

    func makeObstacle() -> SKSpriteNode {
        let obstacle: SKSpriteNode = SKSpriteNode(imageNamed: "Cannon")
        obstacle.name = kObstacleName
        obstacle.physicsBody = SKPhysicsBody(circleOfRadius: obstacle.frame.size.height / 2)
        obstacle.physicsBody?.dynamic = false
        obstacle.physicsBody?.categoryBitMask = kObstacleCategory
        obstacle.physicsBody?.contactTestBitMask = 0x0
        obstacle.physicsBody?.collisionBitMask = 0x0
        return obstacle
    }

    // MARK: Contact
    func didBeginContact(contact: SKPhysicsContact) {
        contactQueue += [contact]
    }

    func handleContact(contact: SKPhysicsContact) {
        // 1
        // Ensure you haven't already handled this contact and removed its nodes
        guard let bodyANode = contact.bodyA.node,
            let bodyBNode = contact.bodyB.node,
            let bodyAName = bodyANode.name,
            let bodyBName = bodyBNode.name
        else { return }

        let nodeNames = [bodyAName, bodyBName]

        if (nodeNames.contains(kBulletName) && nodeNames.contains(kObstacleName)) {
            bodyANode.removeFromParent()
            bodyBNode.removeFromParent()
        }
    }

    func processContactsForUpdate(currentTime: CFTimeInterval) {

        for contact in contactQueue {
            handleContact(contact)
            contactQueue.removeFirst()
        }
    }

}
