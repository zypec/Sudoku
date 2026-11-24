//
//  ContentView.swift
//  Sudoku
//
//  Created by Emre Kaya on 26.10.2024.
//

import SwiftUI

struct HomeView_Placeholder: View {
    
    var body: some View {
        VStack() {
            Text("Sudoku")
                .font(.largeTitle)
            
            Spacer()
            
            Button(action: {}) {
                Text("Play")
            }.buttonStyle(PlayButton())
        }
        .padding()
    }
}

#Preview {
    HomeView_Placeholder()
}
