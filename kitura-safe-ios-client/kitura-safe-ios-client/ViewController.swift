//
//  ViewController.swift
//  kitura-safe-ios-client
//
//  Created by David Okun on 5/30/19.
//  Copyright © 2019 David Okun. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let disasterSocketClient = DisasterSocketClient(address: "localhost:8080")
        disasterSocketClient.delegate = self
        disasterSocketClient.attemptConnection()
    }
}

extension ViewController: DisasterSocketClientDelegate {
    func statusReported(client: DisasterSocketClient, person: Person) {
        print("")
    }
    
    func clientConnected(client: DisasterSocketClient) {
        print("")
    }
    
    func clientDisconnected(client: DisasterSocketClient) {
        print("")
    }
    
    func clientErrorOccurred(client: DisasterSocketClient, error: Error) {
        print("")
    }
}
