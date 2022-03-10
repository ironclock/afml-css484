//
//  OutputView.swift
//  AudioFeaturesCSS484
//
//  Created by Jon Caceres, Derek Slater on 3/5/22.
//

import SwiftUI
import AVKit

struct OutputView: View {
    
    @State var audioOutput: [Output]?
    @State var audioPlayer: AVAudioPlayer!
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    let size: CGFloat = 15
    
    var headerView: some View {
        LazyVGrid(columns: columns) {
            Text("filename")
                .font(.system(size: 12))
            Text("model label")
                .font(.system(size: 12))
            Text("play")
                .font(.system(size: 12))
            Text("ground truth")
                .font(.system(size: 12))
            Text("match")
                .font(.system(size: 12))
        }
        .background(Color.darkGray)
    }
    
    var body: some View {
        
        ScrollView {
            LazyVGrid(columns: columns, spacing: 5, pinnedViews: [.sectionHeaders]) {
                if let audioOutput = audioOutput {
                    //                    HStack {
                    Section(header: headerView) {
                        //                    }
                        ForEach(audioOutput.indices, id: \.self) { index in
                            //                VStack (spacing: 0) {
                            //                    HStack {
                            Text("\(audioOutput[index].fileName)")
                                .font(.system(size: size))
                            //                            .frame(width: 75)
                            Text("\(audioOutput[index].isMusic)")
                                .font(.system(size: size))
                            //                            .frame(width: 50)
                            //                        HStack {
                            Image(systemName: "play.circle.fill").resizable()
                                .frame(width: 15, height: 15)
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.green)
                                .onTapGesture {
                                    playAudio(audioFile: "audioFiles/\(audioOutput[index].fileName).wav")
                                }
                            //                        }
                            //                        .frame(width: 50)
                            Text(audioOutput[index].groundTruth)
                                .font(.system(size: size))
                            if(audioOutput[index].groundTruth == audioOutput[index].isMusic) {
                                Text("✅")
                            } else {
                                Text("❌")
                            }
                            //                            .frame(width: 75)
                            //                    }
                        }
                    }
                }
                //                .padding(0)
                //                .lineSpacing(0)
            }
        }
    }
    
    
    func playAudio(audioFile: String) -> Void {
        guard let audioData = Bundle.main.path(forResource: audioFile, ofType: nil) else {
            print("could not find audio file")
            return
        }
        
        let url = URL(fileURLWithPath: audioData)
        
        do {
            self.audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.play()
            //            print(audioPlayer.settings)
        } catch {
            print("error playing audio file")
        }
    }
}

