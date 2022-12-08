//
//  ContentView.swift
//  Demo
//
//  Created by Clay Ellis on 12/7/22.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            Text(NSLocalizedString("copy", value: "One", comment: ""))
            Text(NSLocalizedString("copy", value: "Two", comment: ""))
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
