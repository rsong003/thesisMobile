//
//  ViewController.swift
//  LiveDontDie
//
//  Created by Timothy Yoon on 8/30/17.
//  Copyright © 2017 Timothy Yoon. All rights reserved.
//

import Mapbox
import UIKit
import SceneKit
import ARKit
import Mapbox

class MBXCompassMapView: MGLMapView, MGLMapViewDelegate {
    
    var isMapInteractive : Bool = true {
        didSet {
            self.isZoomEnabled = false
            self.isScrollEnabled = false
            self.isPitchEnabled = false
            self.isRotateEnabled = false
        }
    }
    
    override convenience init(frame: CGRect, styleURL: URL?) {
        self.init(frame: frame)
        self.styleURL = styleURL
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.delegate = self
        self.alpha = 0.8
        self.delegate = self
        hideMapSubviews()
    }
    
    override func layoutSubviews() {
        self.layer.cornerRadius = self.frame.width / 2
    }
    
    private func hideMapSubviews() {
        self.logoView.isHidden = true
        self.attributionButton.isHidden = true
        self.compassView.isHidden = true
    }
    
    func mapViewWillStartLoadingMap(_ mapView: MGLMapView) {
        self.userTrackingMode = .followWithHeading
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setMapViewBorderColorAndWidth(color: CGColor, width: CGFloat) {
        self.layer.borderWidth = width
        self.layer.borderColor = color
    }
}

extension MBXCompassMapView {
    func setupUserTrackingMode() {
        self.showsUserLocation = true
        self.setUserTrackingMode(.followWithHeading, animated: false)
        self.displayHeadingCalibration = false
    }
}

class ViewController: UIViewController, ARSCNViewDelegate, MGLMapViewDelegate {
    var currentScore: Int = 0
    var compass : MBXCompassMapView!
    var progress: Int = 0
    var markers: Array<SCNNode>?
    var monster: SCNNode?
    var monsterRange: Float = 30
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var progressLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        let scene = SCNScene(named: "art.scnassets/main.scn")!
        markers = Init.initMarkers(scene: scene)
        sceneView.scene = scene
        
        compass = MBXCompassMapView(frame: CGRect(x: 20,
                                                  y: 20,
                                                  width: view.bounds.width / 3,
                                                  height: view.bounds.width / 3),
                                    styleURL: URL(string: "mapbox://styles/jordankiley/cj5eeueie1bsa2rp4swgcteml"))
        
        compass.isMapInteractive = false
        compass.tintColor = .black
        compass.delegate = self
        view.addSubview(compass)
        
        
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tap)
        
        var timer = Timer()
        
        //timer to calculate distance
        
        func scheduledTimerWithTimeInterval(){
            timer = Timer.scheduledTimer(timeInterval: 1/60, target: self, selector: #selector(self.FrameTimer), userInfo: nil, repeats: true)
        }
        
        //timer to instantiate monster
        
        func monsterTimer(){
            timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.monsterTimer), userInfo: nil, repeats: true)
        }
        
        scheduledTimerWithTimeInterval()
        monsterTimer()
    }
    
    @objc func handleTap(_ gestureRecognizer: UIGestureRecognizer) {
        let p = gestureRecognizer.location(in: sceneView)
        let hitResults = sceneView.hitTest(p, options: [:])
        
        if hitResults.count > 0 {
            let node = hitResults[0].node
            progress = progress + 1
            let message = String(progress) + " of 8 notes collected."
            Animations.displayNotification(message: message, label: progressLabel)
            Animations.grab(node: node, sceneView: sceneView)
        }
    }
    
    @objc func FrameTimer(){
        
        for node in markers! {
            if Init.calculateDistance(sceneView: sceneView, node: node) < 3 {
                Init.renderNote(sceneView: sceneView, node: node)
            }
        }
        if monster != nil {
            if(sceneView.scene.rootNode.childNode(withName: monster!.name!, recursively: true) != nil){
                let monsterDistance = Init.calculateDistance(sceneView: sceneView, node: monster!)
                print(monsterDistance)
                //fade out monster at large distances
                if monsterDistance > 30 && monster!.opacity == 1 {
                    Animations.fadeOut(node: monster!)
                } else if monsterDistance < 30 && monster!.opacity == 0 {
                    Animations.fadeIn(node: monster!)
                }
                
                //remove monster from game is player is too far from monster
                if monsterDistance > 35 {
                    monster?.removeFromParentNode()
                }
                
                if monsterDistance < 2 {
                    monster?.removeAllActions()
                    Animations.monsterAttack(sceneView: sceneView, node: monster!)
                } else {
                    Animations.moveMonster(sceneView: sceneView, node: monster!)
                }
            }
        }
       currentScore = Init.calculateScore(score: currentScore, currentProgress: progress)
    }
    
    @objc func monsterTimer(){
        monsterRange = monsterRange - 1
        if monster == nil || sceneView.scene.rootNode.childNode(withName: monster!.name!, recursively: true) == nil {
            print("monster is rendered")
            monster = Init.initMonster(sceneView: sceneView, range: monsterRange)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
}
