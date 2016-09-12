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

class GameScene: SKScene, SKPhysicsContactDelegate {

    let Pi = CGFloat(M_PI)
    let PlayerMissileSpeed: CGFloat = 300

    let kWorld = "world"
    let kCamera = "camera"
    let kOverlay = "overlay"
    let kElementName = "element"
    let kObstacleName = "obstacle"
    let kBulletName = "bullet"

    let kObstacleCategory: UInt32 = 0x1 << 0
    let kBulletCategory: UInt32 = 0x1 << 1
    let kElementCategory: UInt32 = 0x1 << 2
    let kSceneEdgeCategory: UInt32 = 0x1 << 3
    let kOtherElementCategory: UInt32 = 0x1 << 4
    let kWorldBoundaryCategory: UInt32 = 0x1 << 5

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

            self.anchorPoint = CGPointMake(0.5, 0.5)

            // Camera setup
            self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.world = SKNode()
            self.world?.name = kWorld
            addChild(self.world!)

            let cam = SKCameraNode() // initialize and assign an instance of SKCameraNode to the cam variable.
            self.camera = cam
            self.camera?.name = kCamera
            self.world?.addChild(cam)

            // UI setup
            self.overlay = SKNode()
            self.overlay?.zPosition = 10
            self.overlay?.name = kOverlay
            addChild(self.overlay!)
        }
    }

    override func didMoveToView(view: SKView) {
        setupScene()
        guard isCreated else { return }

        self.physicsWorld.contactDelegate = self
//        world?.physicsBody = SKPhysicsBody(edgeLoopFromRect: view.frame)
        world?.physicsBody?.dynamic = false
        world?.physicsBody?.affectedByGravity = false
        world?.physicsBody?.categoryBitMask = kWorldBoundaryCategory;

        // set scene size to match view
        size = view.bounds.size
        backgroundColor = SKColor(red: 250.0 / 255, green: 250.0 / 255, blue: 245.0 / 255, alpha: 0.5)

        let grid = Grid(blockSize: 40.0, rows: 100, cols: 100)
        grid.anchorPoint = CGPointMake(0.5, 0.5)
        grid.zPosition = -100
        world?.addChild(grid)

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

        moveAnalogStick.position = CGPoint(x: self.frame.minX + moveAnalogStick.radius + 15, y: self.frame.minY + moveAnalogStick.radius + 15)
        overlay?.addChild(moveAnalogStick)

        rotateAnalogStick.position = CGPoint(x: self.frame.maxX - rotateAnalogStick.radius - 15, y: self.frame.minY + rotateAnalogStick.radius + 15)
        overlay?.addChild(rotateAnalogStick)

        // set up joySticker
        moveAnalogStick.stick.image = UIImage(named: ImageNameKey.Sticker.rawValue)
        moveAnalogStick.substrate.image = UIImage(named: ImageNameKey.SubSticker.rawValue)
        rotateAnalogStick.stick.image = UIImage(named: ImageNameKey.Sticker.rawValue)
        rotateAnalogStick.substrate.image = UIImage(named: ImageNameKey.SubSticker.rawValue)
        rotateAnalogStick.zRotation = Pi / 4

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

    func makeElement() -> SKSpriteNode {
        let element = SKSpriteNode(imageNamed: ImageNameKey.FireElement.rawValue)
        element.name = kElementName
        element.physicsBody?.categoryBitMask = kElementCategory
        element.physicsBody?.contactTestBitMask = 0x0
        element.physicsBody?.collisionBitMask = kWorldBoundaryCategory
        return element
    }

    func makeBullet() -> SKSpriteNode {
        let bullet = SKSpriteNode(imageNamed: ImageNameKey.FireBall.rawValue)
        bullet.name = kBulletName
        bullet.physicsBody = SKPhysicsBody(rectangleOfSize: bullet.frame.size)
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.categoryBitMask = kBulletCategory
        bullet.physicsBody?.contactTestBitMask = kObstacleCategory
        bullet.physicsBody?.collisionBitMask = kWorldBoundaryCategory
        return bullet
    }

    func makeObstacle() -> SKSpriteNode {
        let obstacle: SKSpriteNode = SKSpriteNode(imageNamed: ImageNameKey.DebugObstacle.rawValue)
        obstacle.name = kObstacleName
        obstacle.physicsBody = SKPhysicsBody(circleOfRadius: obstacle.frame.size.height / 2)
        obstacle.physicsBody?.dynamic = false
        obstacle.physicsBody?.categoryBitMask = kObstacleCategory
        obstacle.physicsBody?.contactTestBitMask = 0x0
        obstacle.physicsBody?.collisionBitMask = kWorldBoundaryCategory
        return obstacle
    }

    // MARK: Contact
    func didBeginContact(contact: SKPhysicsContact) {
        contactQueue += [contact]
    }

    func handleContact(contact: SKPhysicsContact) {

        let categoryMask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        let collisionMask = contact.bodyA.collisionBitMask | contact.bodyB.collisionBitMask

        print(contact.bodyA.node?.name)
        print(contact.bodyB.node?.name)

        switch categoryMask {
        case kObstacleCategory | kBulletCategory:
            contact.bodyA.node?.removeFromParent()
            contact.bodyB.node?.removeFromParent()
            break
        case kWorldBoundaryCategory:
            print("reach boundary")
            break
        default: break

        }

        switch collisionMask {
        case kWorldBoundaryCategory:
            break
        default: break

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
            return CGPointMake(frame.origin.x + frame.width/2, frame.origin.y + frame.height/2)
        }
    }
}
