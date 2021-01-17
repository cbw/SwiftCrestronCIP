//
//  ContentView.swift
//  CIPSampleApp
//
//  Created by Chris Wilson on 1/16/21.
//

import SwiftUI

private enum DigitalJoinIcon: String {
    case high = "arrow.up.circle.fill"
    case low = "arrow.down.circle.fill"
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

struct FilledButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(configuration.isPressed ? .gray : .white)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(8)
    }
}

struct DigitalSignalsControl: View {
    @ObservedObject private var state = ObservableState(store: appStore)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack() {
                Button("Pulse 1", action: { appStore.dispatch(Digital1Pressed()) })
                
                Spacer()
                
                Text("Digital Join 1")
                    .font(.title3)
                    .padding(.leading)
                
                Image(systemName: state.current.swiftPress1 ? DigitalJoinIcon.high.rawValue : DigitalJoinIcon.low.rawValue)
                    .font(.system(size: 20, weight: .light))
                    .imageScale(.large)
            }
            
            
            HStack() {
                Button("Pulse 2", action: { appStore.dispatch(Digital2Pressed()) })
                
                Spacer()
                
                Text("Digital Join 2")
                    .font(.title3)
                    .padding(.leading)
                
                Image(systemName: state.current.swiftPress2 ? DigitalJoinIcon.high.rawValue : DigitalJoinIcon.low.rawValue)
                    .font(.system(size: 20, weight: .light))
                    .imageScale(.large)
                
            }
        }
        .buttonStyle(FilledButton())
    }
}

struct AnalogSignalsControl: View {
    @ObservedObject private var state = ObservableState(store: appStore)
    @State private var analogVal = 0.0
    
    var body: some View {
        VStack(alignment: .center, spacing: nil) {
            Slider(
                value: $analogVal,
                in: 0...65535,
                step: 1,
                onEditingChanged: { editing in
                    if !editing {
                        appStore.dispatch(AnalogValue1Changed(value: UInt16(analogVal)))
                    }
                }
            )
            
            HStack() {
                Spacer()
                Text(String(format: "Value: %.0f", analogVal))
                    .font(.caption)
                    
            }
            .padding(.bottom)
            
            
            Text("Analog Join 1 Value: \(state.current.swiftAnalog1)")
                .fontWeight(.medium)
        }
    }
}

struct SerialSignalsControl: View {
    @ObservedObject private var state = ObservableState(store: appStore)
    @State private var text = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: nil) {
            HStack() {
                TextField(
                    "String to send",
                    text: $text
                )
                .padding(.all, 6.0)
                .border(Color(UIColor.separator))
                
                Button(action: {
                    appStore.dispatch(Serial1Send(value: text))
                    text = ""
                    self.hideKeyboard()
                }) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 20, weight: .light))
                        .imageScale(.large)
                }
                .buttonStyle(DefaultButtonStyle())
            }
            .padding(.bottom)
            
            Text("Serial Join 1 Received Text").font(/*@START_MENU_TOKEN@*/.subheadline/*@END_MENU_TOKEN@*/)
            
            ScrollView {
                Text(String(state.current.swiftSerialEcho1 ?? ""))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 75, alignment: .topLeading)
                   
            }
            .background(Color("Subtle Background"))
        }
    }
}

struct StatusItemView: View {
    private var color: Color
    private var message: String
    
    init(color: Color, message: String) {
        self.color = color
        self.message = message
    }
    
    var body: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 12, weight: .light))
            .imageScale(.small)
            .foregroundColor(color)
        Text(message)
    }
    
}

struct ConnectionStatusView: View {
    @ObservedObject private var state = ObservableState(store: appStore)
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack() {
                    if (state.current.connectionState == .connected) {
                        StatusItemView(color: .green, message: "Connected")
                    } else if state.current.connectionState == .connecting || state.current.connectionState == .retrying {
                        StatusItemView(color: .yellow, message: "Connecting")
                    } else {
                        StatusItemView(color: .red, message: "Disconnected")
                    }
                }
                
                HStack() {
                    if state.current.registeredWithProcessor {
                        StatusItemView(color: .green, message: "Registered")                } else {
                            StatusItemView(color: .red, message: "Not Registered")
                        }
                }
            }
            
            Spacer()
            
            if state.current.connectionState == .connected {
                Button("Disconnect", action: { appStore.dispatch(Disconnect()) })
                    .buttonStyle(DefaultButtonStyle())
                    .foregroundColor(.red)
            }
            if state.current.connectionState == .disconnected {
                Button("Connect", action: { appStore.dispatch(Connect()) })
                    .buttonStyle(DefaultButtonStyle())
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject private var state = ObservableState(store: appStore)
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text("Swift CIP Demo").font(.largeTitle).padding(.bottom)

                ScrollView() {
                    HStack() {
                        Text("Signals").font(.title).padding(.bottom)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 70) {
                        DigitalSignalsControl()
                        AnalogSignalsControl()
                        SerialSignalsControl()
                    }
                }
                
                Spacer()
                ConnectionStatusView()
            }
            .padding()
            Spacer()
        }
        .buttonStyle(FilledButton())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().preferredColorScheme(.dark)
        //.buttonStyle(FilledButton())
    }
}
