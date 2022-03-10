//
//  ContentView.swift
//  AudioFeaturesCSS484
//
//  Created by Jon Caceres, Derek Slater on 3/3/22.
//

import SwiftUI
import UIKit

extension Color {
    static let uwPurple = Color(red: 74 / 255, green: 46 / 255, blue: 131 / 255)
    static let lightGray = Color(red: 140 / 255, green: 140 / 255, blue: 140 / 255)
    static let darkGray = Color(red: 54 / 255, green: 54 / 255, blue: 54 / 255)
}

struct ContentView: View {
    
    @State var energyDistribution: Bool = true
    @State var zeroCrossingRate: Bool = true
    @State var averageEnergy: Bool = true
    
    @State var showOutputView = false
    
    @State var didTap = false
    
    let featureExtraction = FeatureExtraction()
    let ml = MachineLearning()
    
    @State var audioOutput: [Output]?
    
    @State var alreadyRun = false
    
    var body: some View {
        NavigationView {
            VStack {
                VStack {
                    Text("ML with Audio Features")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .onAppear {
                            if didTap == true {
                                showOutputView = false
                                didTap = false
                            }
                        }
                    Text("by Derek Slater & Jon Caceres")
                    Text("CSS 484 - Winter 2022 UWB")
                    Spacer()
                }
                .frame(minWidth: 0, maxHeight: 200, alignment: .topLeading)
                VStack {
                    Text("Features")
                    Toggle(isOn: $energyDistribution) {
                        Text("Energy Distribution")
                    }
                    .disabled(true)
                    Toggle(isOn: $zeroCrossingRate) {
                        Text("Zero Crossing Rate")
                    }
                    .disabled(true)
                    Toggle(isOn: $averageEnergy) {
                        Text("Average Energy")
                    }
                    .disabled(true)
                }
                .frame(width: 300)
                VStack {
                        Button("Run") {
                            self.showOutputView = true
                            self.didTap = true
                            Task {
                                if alreadyRun == false {
                                    print("has not already run")
                                    audioOutput = await runEntireModel()
                                } else {
                                    print("already ran, no need to run model again")
                                }
                            }
                        }
                        .padding()
                        .background(Color.uwPurple)
                        .foregroundColor(didTap ? .gray : .white)
                        .font(.headline)
                        .disabled(didTap ? true : false)
                        .cornerRadius(5)
                    NavigationLink(destination: OutputView(audioOutput: audioOutput), isActive: $showOutputView) { }
                        .navigationBarTitle(Text("Home"), displayMode: .inline)
                    }
                .frame(width: 300)
                .padding()
            }
        }
    }
    
    func runEntireModel() async -> [Output] {
        
        alreadyRun = true
        
        do {
            let features = await featureExtraction.transformAllFiles()
            
            let output = await ml.runModel(features: features)
            
            self.showOutputView = true
            
            return output
            
            //            print(output)
            
        }
    }
}
