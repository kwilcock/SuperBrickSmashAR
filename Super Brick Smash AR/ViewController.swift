//
//  ViewController.swift
//  Super Brick Smash AR
//
//  Created by Karl Wilcock on 11/10/17.
//  Copyright © 2017 Karl Wilcock. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var isWallPlaced = false
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
        
        self.sceneView.autoenablesDefaultLighting = true
        self.sceneView.automaticallyUpdatesLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
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
            let rotate = simd_float4x4(SCNMatrix4MakeRotation(sceneView.session.currentFrame!.camera.eulerAngles.y, 0, 1, 0))
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -1.5
            translation.columns.3.y = 0.5
            let finalTransform = simd_mul(rotate, translation)
            print(finalTransform.columns.3)
            let sphereNode = sceneView.pointOfView?.childNode(withName: "bullet", recursively: false)
            let force = SCNVector3(x: finalTransform.columns.3.x, y: finalTransform.columns.3.y, z: finalTransform.columns.3.z)
            sphereNode?.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            sphereNode?.physicsBody?.applyForce(force, asImpulse: true)
        }
        guard let node = hitTestResults.first?.node else {
            let hitTestResultsWithFeaturePoints = sceneView.hitTest(tapLocation, types: .estimatedHorizontalPlane)
            if let hitTestResultWithFeaturePoints = hitTestResultsWithFeaturePoints.first {
                if (!isWallPlaced) {
                    let rotate = simd_float4x4(SCNMatrix4MakeRotation(sceneView.session.currentFrame!.camera.eulerAngles.y, 0, 1, 0))
                    let finalTransform = simd_mul(hitTestResultWithFeaturePoints.worldTransform, rotate)
                    sceneView.session.add(anchor: ARAnchor(transform: finalTransform))
                    createSphere(x: 0, y: -0.04, z: -0.1)
                    isWallPlaced = true
                }
            }
            return
        }
        node.removeFromParentNode()
    }
    func createSphere(x: Float, y: Float, z: Float) {
        let sphereGeometry = SCNSphere(radius: 0.01)
        let sphereNode = SCNNode(geometry: sphereGeometry)
        sphereNode.position = SCNVector3(x, y, z)
        sphereNode.name = "bullet"
        //        sphereNode.physicsBody?.velocity = SCNVector3(2, 0, 0);
        sceneView.pointOfView?.addChildNode(sphereNode)
        
    }
    func createBullet(node:SCNNode) {
        let sphereGeometry = SCNSphere(radius: 0.01)
        let sphereNode = SCNNode(geometry: sphereGeometry)
        sphereNode.position = SCNVector3(0.0, -0.04, 0.0)
        sphereNode.name = "bullet"
        let force = SCNVector3(x: 0, y: 0, z: -1)
        //            let position = SCNVector3(x: 0, y: 0, z: 0)
        sceneView.scene.rootNode.addChildNode(sphereNode)
        sphereNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        sphereNode.physicsBody?.applyForce(force, asImpulse: true)
    }
    func createCube(node: SCNNode, x: Float, y: Float, height: Float, width: Float, length: Float){
        let boxGeometry = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(length), chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: "texture.jpg")
        boxGeometry.materials = [material]
        let boxNode = SCNNode(geometry: boxGeometry)
        boxNode.position = SCNVector3(x, y, 0)
        boxNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        node.addChildNode(boxNode)
    }
    
    func createWall(node: SCNNode){
        var startingX = -0.1
        for _ in 1...6 {
            var startingY = 0.0
            for _ in 1...4 {
                createCube(node: node, x: Float(startingX), y: Float(startingY), height: 0.1, width: 0.1, length: 0.1)
                startingY += 0.1
            }
            startingX += 0.1
        }
    }
}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}
