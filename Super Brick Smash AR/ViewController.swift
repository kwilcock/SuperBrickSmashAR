import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    struct CollisionCategory: OptionSet {
        let rawValue: Int
        
        static let bullet  = CollisionCategory(rawValue: 1 << 0)
        static let wall = CollisionCategory(rawValue: 1 << 1)
    }
    
    @IBOutlet var sceneView: ARSCNView!
    var isWallPlaced = false
    var planes: [String : SCNNode] = [:]
    var timer = Timer()
    var allBricks = [SCNNode]()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        addTapGestureToSceneView()
        // Set the scene to the view
        sceneView.scene = scene
        sceneView.scene.physicsWorld.contactDelegate = self
        
        sceneView.scene.physicsWorld.gravity = SCNVector3(0, -2.8, 0)
        
        self.sceneView.autoenablesDefaultLighting = true
        self.sceneView.automaticallyUpdatesLighting = true
        timer = Timer.scheduledTimer(timeInterval: 5, target: self,   selector: (#selector(ViewController.updateTimer)), userInfo: nil, repeats: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    @objc func updateTimer() {
        if (isWallPlaced) {
            let brick = allBricks[Int(arc4random_uniform(80))]
            let color = SCNMaterial()
            color.diffuse.contents = UIColor(red: 1, green: 0, blue: 0, alpha: 0.6)
            brick.geometry?.materials = [color]
            brick.name = "active"
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if !anchor.isKind(of: ARPlaneAnchor.self) {
            DispatchQueue.main.async {
                self.createWall(node: node)
            }
        } else {
            let planeAnchor = anchor as? ARPlaneAnchor
            let plane = SCNBox(width: CGFloat((planeAnchor?.extent.x)!), height: 0.005, length: CGFloat((planeAnchor?.extent.z)!), chamferRadius: 0)
            let color = SCNMaterial()
            color.diffuse.contents = UIColor(red: 0, green: 0, blue: 1, alpha: 0.1)
            plane.materials = [color]
            let planeNode = SCNNode(geometry: plane)
            planeNode.position = SCNVector3Make((planeAnchor?.center.x)!, -0.005, (planeAnchor?.center.z)!)
            let body = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: plane, options: nil))
            body.restitution = 0.0
            body.friction = 1.0
            planeNode.physicsBody = body
            node.addChildNode(planeNode)
            let key = planeAnchor?.identifier.uuidString
            self.planes[key!] = planeNode
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let key = planeAnchor.identifier.uuidString
        if let existingPlane = self.planes[key] {
            if let geo = existingPlane.geometry as? SCNBox {
                geo.width = CGFloat(planeAnchor.extent.x)
                geo.length = CGFloat(planeAnchor.extent.z)
            }
            existingPlane.position = SCNVector3Make(planeAnchor.center.x, -0.005, planeAnchor.center.z)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let key = planeAnchor.identifier.uuidString
        if let existingPlane = self.planes[key] {
            existingPlane.removeFromParentNode()
            self.planes.removeValue(forKey: key)
        }
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        if (contact.nodeA.name == "bullet") {
            contact.nodeB.removeFromParentNode()
        }
        if (contact.nodeB.name == "bullet" && contact.nodeA.name == "active") {
            contact.nodeA.removeFromParentNode()
        }
    }
    
    func addTapGestureToSceneView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.didTap(withGestureRecognizer:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func didTap(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation)
        if (isWallPlaced) {
            let rotateX = simd_float4x4(SCNMatrix4MakeRotation(sceneView.session.currentFrame!.camera.eulerAngles.y, 0, 1, 0))
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -3.5
            let firstTransform = simd_mul(rotateX, translation)
            let rotateY = simd_float4x4(SCNMatrix4MakeRotation(sceneView.session.currentFrame!.camera.eulerAngles.x, 1, 0, 0))
            let secondTransform = simd_mul(rotateY, translation)
            let sphereNode = createSphere(x: 0, y: -0.04, z: -0.1)
            let force = SCNVector3(x: firstTransform.columns.3.x, y: secondTransform.columns.3.y, z: firstTransform.columns.3.z)
            sphereNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            sphereNode.physicsBody?.applyForce(force, asImpulse: true)
        }
        guard let _ = hitTestResults.first?.node else {
            let hitTestResultsWithFeaturePoints = sceneView.hitTest(tapLocation, types: .estimatedHorizontalPlane)
            if let hitTestResultWithFeaturePoints = hitTestResultsWithFeaturePoints.first {
                if (!isWallPlaced) {
                    let rotate = simd_float4x4(SCNMatrix4MakeRotation(sceneView.session.currentFrame!.camera.eulerAngles.y, 0, 1, 0))
                    let finalTransform = simd_mul(hitTestResultWithFeaturePoints.worldTransform, rotate)
                    sceneView.session.add(anchor: ARAnchor(transform: finalTransform))
                    isWallPlaced = true
                }
            }
            return
        }
    }
    func createSphere(x: Float, y: Float, z: Float) -> SCNNode {
        let sphereGeometry = SCNSphere(radius: 0.01)
        let sphereNode = SCNNode(geometry: sphereGeometry)
        sphereNode.position = SCNVector3(x, y, z)
        sphereNode.name = "bullet"
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: sphereGeometry, options: nil))
        physicsBody.mass = 1.25
        physicsBody.restitution = 0.25
        physicsBody.friction = 0.75
        physicsBody.categoryBitMask = CollisionCategory.bullet.rawValue
        physicsBody.contactTestBitMask = CollisionCategory.wall.rawValue
        sphereNode.physicsBody = physicsBody
        sceneView.pointOfView?.addChildNode(sphereNode)
        return sphereNode
    }
    
    func createCube(node: SCNNode, x: Float, y: Float){
        var nodeModel:SCNNode!
        let nodeName = "glassbrick"
        let physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        physicsBody.categoryBitMask = CollisionCategory.wall.rawValue
        physicsBody.contactTestBitMask = CollisionCategory.bullet.rawValue
        let modelScene = SCNScene(named: "art.scnassets/glassbrick.dae")!
        nodeModel =  modelScene.rootNode.childNode(withName: nodeName, recursively: true)
        nodeModel.position = SCNVector3(x, y, 0)
        nodeModel.scale = SCNVector3(0.05, 0.1, 0.05)
        nodeModel.physicsBody = physicsBody
        allBricks.append(nodeModel)
        node.addChildNode(nodeModel)
    }
    
    func createWall(node: SCNNode){
        let scaleX = 2.0
        let scaleY = 2.0
        var startingX = -0.1 * 6 * scaleX
        for _ in 1...9 {
            var startingY = 0.0
            for _ in 1...11 {
                createCube(node: node, x: Float(startingX), y: Float(startingY))
                startingY += 0.05 * scaleY
            }
            startingX += 0.1 * scaleX
        }
    }
}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}

