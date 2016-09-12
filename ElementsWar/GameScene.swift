//
//  GameScene.swift
//  ElementsWar
//
//  Created by Sidney on 9/9/16.
//  Copyright (c) 2016 Siqi. All rights reserved.
//

import SpriteKit

enum ImageNameKey: String {
    case FireElement = "FireElement"
    case ElectricElement = "ElectricElement"
    case StoneElement = "StoneElement"
    case RancherElement = "RancherElement"
    case FireBall = "FireBall"
    case DebugObstacle = "Cannon"
    case Sticker = "Sticker"
    case SubSticker = "SubSticker"
}

enum NodeName: String {
    case kWorld = "world"
    case kCamera = "camera"
    case kOverlay = "overlay"
    case kElementName = "element"
    case kObstacleName = "obstacle"
    case kBulletName = "bullet"
}

enum ContactType: UInt32 {
    case Bullet = 1
    case Element = 2
    case Obstacle = 4
    case WorldBoundary = 8
    case SceneBoundary = 16
    case OtherElement = 32
}

enum ZPositions: Float {
    case WorldBackgound = -100
    case WorldElement = 0
    case Overlay = 100
}

class GameScene: SKScene, SKPhysicsContactDelegate {

    let Pi = CGFloat(M_PI)
    let PlayerMissileSpeed: CGFloat = 300
    let GridRows = 10

    // Flag indicating whether we've setup the camera system yet.
    var isCreated: Bool = false

    // The root node of your game world. Attach game entities
    var world: SKNode?

    // The root node of our UI. Attach control buttons & state
    var overlay: SKNode?

    var playerElement: SKSpriteNode?

    let moveAnalogStick = AnalogJoystick(diameter: 100)
    let rotateAnalogStick = AnalogJoystick(diameter: 100)

    let missileShootSound = SKAction.playSoundFileNamed("Shoot.wav", waitForCompletion: false)
    let collisionSound = SKAction.playSoundFileNamed("Collision", waitForCompletion: false)
    let hitSound = SKAction.playSoundFileNamed("Hit", waitForCompletion: false)

    var isFirePressed = false

    // Time of last update(currentTime:) call
    var lastUpdateTime = NSTimeInterval(0)

    // Seconds elapsed since last action
    var timeSinceLastAction = NSTimeInterval(0)

    // Seconds before performing next action. Choose a default value
    var timeUntilNextAction = NSTimeInterval(0.7)

    // contact
    var contactQueue = [SKPhysicsContact]()

    func setupScene() {
        if !isCreated {
            isCreated = true
            self.physicsWorld.gravity = CGVectorMake(0, 0);
            self.physicsWorld.contactDelegate = self

            self.anchorPoint = CGPointMake(0.5, 0.5)

            // Camera setup
            self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.world = makeWorld()
            addChild(self.world!)

            let cam = SKCameraNode() // initialize and assign an instance of SKCameraNode to the cam variable.
            self.camera = cam
            self.camera?.name = NodeName.kCamera.rawValue
            self.world?.addChild(cam)

            // UI setup
            self.overlay = SKNode()
            self.overlay?.zPosition = 10
            self.overlay?.name = NodeName.kOverlay.rawValue
            addChild(self.overlay!)
        }
    }

    override func didMoveToView(view: SKView) {
        setupScene()
        guard isCreated else { return }
        // set scene size to match view
        size = view.bounds.size
        backgroundColor = SKColor(red: 250.0 / 255, green: 250.0 / 255, blue: 245.0 / 255, alpha: 0.5)

        // TODO: add player
        self.playerElement = makeElement()
        if let element = playerElement {
            world?.addChild(element)
            element.anchorPoint = CGPointMake(0.5, 0.5)
            cameraOnNode(element)
        }

        // Add controllers
        setupControllers()

    }

    override func didFinishUpdate() {
        if let camera = self.camera {
            self.centerOnNode(camera)
        }
    }

    func centerOnNode(node: SKNode) {
        if let scene = node.scene,
            let parent = node.parent {
                let cameraPositionInScene: CGPoint = scene.convertPoint(node.position, fromNode: parent)
                parent.position = CGPoint(x: parent.position.x - cameraPositionInScene.x, y: parent.position.y - cameraPositionInScene.y)
        }
    }

    func cameraOnNode(node: SKNode) {
        self.camera?.position = node.position
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            if let world = self.world {
                let location = touch.locationInNode(world)
                if !moveAnalogStick.containsPoint(location) && !rotateAnalogStick.containsPoint(location) {
                    let obstacle = makeObstacle()
                    obstacle.position = location
                    world.addChild(obstacle)
                }
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
        let margin: CGFloat = 20
        moveAnalogStick.position = CGPoint(x: self.frame.minX + moveAnalogStick.radius + margin, y: self.frame.minY + moveAnalogStick.radius + margin)
        overlay?.addChild(moveAnalogStick)

        rotateAnalogStick.position = CGPoint(x: self.frame.maxX - rotateAnalogStick.radius - margin, y: self.frame.minY + rotateAnalogStick.radius + margin)
        overlay?.addChild(rotateAnalogStick)

        // set up joySticker
        moveAnalogStick.stick.image = UIImage(named: ImageNameKey.Sticker.rawValue)
        moveAnalogStick.substrate.image = UIImage(named: ImageNameKey.SubSticker.rawValue)
        rotateAnalogStick.stick.image = UIImage(named: ImageNameKey.Sticker.rawValue)
        rotateAnalogStick.substrate.image = UIImage(named: ImageNameKey.SubSticker.rawValue)

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
            self.cameraOnNode(aN)
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

    func makeWorld() -> SKNode {
        let grid = Grid(blockSize: 40.0, rows: GridRows, cols: GridRows)
        grid.anchorPoint = CGPointMake(0.5, 0.5)
        grid.zPosition = CGFloat(ZPositions.WorldBackgound.rawValue)

        let world = SKSpriteNode()
        world.name = NodeName.kWorld.rawValue
        world.physicsBody = SKPhysicsBody(edgeLoopFromRect: grid.frame)
        world.physicsBody?.dynamic = true
        world.physicsBody?.affectedByGravity = false
        world.physicsBody?.categoryBitMask = ContactType.WorldBoundary.rawValue
        world.physicsBody?.contactTestBitMask = ContactType.Element.rawValue | ContactType.Obstacle.rawValue | ContactType.WorldBoundary.rawValue
        world.physicsBody?.collisionBitMask = ContactType.Element.rawValue | ContactType.Obstacle.rawValue | ContactType.WorldBoundary.rawValue
        world.addChild(grid)
        return world
    }

    func makeElement() -> SKSpriteNode {
        let element = SKSpriteNode(imageNamed: ImageNameKey.FireElement.rawValue)
        element.name = NodeName.kElementName.rawValue
        element.physicsBody = SKPhysicsBody(rectangleOfSize: element.size)
        element.physicsBody?.affectedByGravity = false
        element.physicsBody?.categoryBitMask = ContactType.Element.rawValue
        element.physicsBody?.contactTestBitMask = ContactType.Bullet.rawValue
        element.physicsBody?.collisionBitMask = ContactType.Element.rawValue | ContactType.Obstacle.rawValue | ContactType.WorldBoundary.rawValue
        return element
    }

    func makeBullet() -> SKSpriteNode {
        let bullet = SKSpriteNode(imageNamed: ImageNameKey.FireBall.rawValue)
        bullet.name = NodeName.kBulletName.rawValue
        bullet.physicsBody = SKPhysicsBody(circleOfRadius: bullet.size.width / 2)
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.categoryBitMask = ContactType.Bullet.rawValue
        bullet.physicsBody?.contactTestBitMask = ContactType.Element.rawValue | ContactType.Obstacle.rawValue | ContactType.WorldBoundary.rawValue
        bullet.physicsBody?.collisionBitMask = 0x0
        return bullet
    }

    func makeObstacle() -> SKSpriteNode {
        let obstacle: SKSpriteNode = SKSpriteNode(imageNamed: ImageNameKey.DebugObstacle.rawValue)
        obstacle.name = NodeName.kObstacleName.rawValue
        obstacle.physicsBody = SKPhysicsBody(circleOfRadius: obstacle.size.height / 2)
        obstacle.physicsBody?.dynamic = true
        obstacle.physicsBody?.affectedByGravity = false
        obstacle.physicsBody?.categoryBitMask = ContactType.Obstacle.rawValue
        obstacle.physicsBody?.contactTestBitMask = ContactType.Obstacle.rawValue | ContactType.Element.rawValue | ContactType.WorldBoundary.rawValue
        obstacle.physicsBody?.collisionBitMask = ContactType.Obstacle.rawValue | ContactType.Element.rawValue | ContactType.WorldBoundary.rawValue
        return obstacle
    }

    // MARK: Contact
    func didBeginContact(contact: SKPhysicsContact) {
        contactQueue += [contact]
    }

    func handleContact(contact: SKPhysicsContact) {

        var bodyA: SKPhysicsBody
        var bodyB: SKPhysicsBody

        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            bodyA = contact.bodyA
            bodyB = contact.bodyB
        } else {
            bodyB = contact.bodyA
            bodyA = contact.bodyB
        }

        let categoryMask = bodyA.categoryBitMask | bodyB.categoryBitMask

        let bulletHitObstacleMask = ContactType.Bullet.rawValue | ContactType.Obstacle.rawValue
        let bulletHitElementMask = ContactType.Bullet.rawValue | ContactType.Element.rawValue
        let bulletOverBoundaryMask = ContactType.Bullet.rawValue | ContactType.WorldBoundary.rawValue
        let elementContactObstacleMask = ContactType.Element.rawValue | ContactType.Obstacle.rawValue
        let elementContactElementMask = ContactType.Element.rawValue | ContactType.OtherElement.rawValue

        if categoryMask & bulletHitObstacleMask == bulletHitObstacleMask {
            if let bullet = bodyA.node as? SKSpriteNode,
                let obstacle = bodyB.node as? SKSpriteNode {
                    bulletHitObstacle(bullet, obstacle: obstacle)
            }
        }

        if categoryMask & bulletHitElementMask == bulletHitElementMask {
            if let bullet = bodyA.node as? SKSpriteNode,
                let element = bodyB.node as? SKSpriteNode {
                    bulletHitElement(bullet, element: element)
            }
        }

        if categoryMask & bulletOverBoundaryMask == bulletOverBoundaryMask {
            bodyA.node?.removeFromParent()
        }

        if categoryMask & elementContactObstacleMask == elementContactObstacleMask {
            if let element = bodyA.node as? SKSpriteNode,
                let obstacle = bodyB.node as? SKSpriteNode {
                    elementContactObstacle(element, obstacle: obstacle)
            }
        }

        if categoryMask & elementContactElementMask == elementContactElementMask {
            if let eA = bodyA.node as? SKSpriteNode,
                let eB = bodyB.node as? SKSpriteNode {
                    elementContactElement(eA, eB: eB)
            }
        }
    }

    // MARK: contact functions

    func bulletHitObstacle(bullet: SKSpriteNode, obstacle: SKSpriteNode) {
        bullet.removeFromParent()
        obstacle.removeFromParent()
        self.runAction(SKAction.sequence([self.hitSound]))
    }

    func bulletHitElement(bullet: SKSpriteNode, element: SKSpriteNode) {
        // TODO
        self.runAction(SKAction.sequence([self.hitSound]))
    }

    func elementContactObstacle(element: SKSpriteNode, obstacle: SKSpriteNode) {
        // TODO
        self.runAction(SKAction.sequence([self.collisionSound]))
    }

    func elementContactElement(eA: SKSpriteNode, eB: SKSpriteNode) {
        // TODO
    }

    // MARK: Action functions

    func shootMissle(fromNode node: SKSpriteNode) {
        let bullet = makeBullet()
        let angle = node.zRotation + self.Pi / 2.0
        let shootInitDistance: CGFloat = 60
        world?.addChild(bullet)
        bullet.zRotation = node.zRotation
        bullet.position = CGPointMake(node.center.x + shootInitDistance * cos(angle), node.center.y + shootInitDistance * sin(angle))

        let travelDistance: CGFloat = 1000
        let action = SKAction.moveTo(
            CGPointMake(
                travelDistance * cos(angle) + bullet.position.x,
                travelDistance * sin(angle) + bullet.position.y
            ),
            duration: 6)

        bullet.runAction(SKAction.sequence([self.missileShootSound, action])) {
            bullet.hidden = true
        }
    }

    func processContactsForUpdate(currentTime: CFTimeInterval) {

        for contact in contactQueue {
            handleContact(contact)
            contactQueue.removeFirst()
        }
    }

}

extension SKSpriteNode {
    var center: CGPoint {
        get {
            let frame = self.frame
            return CGPointMake(frame.origin.x + frame.width / 2, frame.origin.y + frame.height / 2)
        }
    }
}
