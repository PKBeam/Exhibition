//
//  AppDelegate.swift
//  Exhibition
//
//  Created by Vincent Liu on 22/11/17.
//  Copyright © 2017 Vincent Liu. All rights reserved.
//

import Cocoa
import CoreGraphics

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
	let menu = NSMenu()

    // list of display modes for the current display
	var displayModes: [CGDisplayMode] = []

    // whether the user should see only modes that are safe to use
    var onlySafeModes = true
    var onlyHidpiModes = true

    // gets the display ID of the display that is currently in focus.
    func getCurrentDisplay() -> CGDirectDisplayID {
        return NSScreen.main!.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
    }
	
	// Return all display modes for main display
	func getAllDisplayModes() -> [CGDisplayMode] {
		// the usage of the option "kCGDisplayShowDuplicateLowResolutionModes" is not documented on developer.apple.com - this is what exposes HiDPI scaled resolutions
		var dispModes = CGDisplayCopyAllDisplayModes(getCurrentDisplay(), [kCGDisplayShowDuplicateLowResolutionModes:true] as CFDictionary) as! [CGDisplayMode]
		
		// sort from highest to lowest
		for display in dispModes {
			for index in 0 ..< dispModes.count {
				if display.height < dispModes[index].height || (display.height == dispModes[index].height && display.pixelHeight < dispModes[index].pixelHeight){
					dispModes.remove(at: dispModes.firstIndex(of: display)!)
					dispModes.insert(display, at: index)
				}
			}
		}
		return dispModes
	}
	
	func showDisplayModes(_ modes: [CGDisplayMode], onlyUsableModes: Bool) {
        var safeModeList: [(String, UInt32)] = []
        var menuIndex = 0;
		for index in 0 ..< modes.count {
			var outputString = ""
            let thisMode = modes[index]
			// add resolution
			outputString += "\(thisMode.width) x \(thisMode.height)"

            // add interlacing information
            // see IOGraphicsTypes.h for a list of flags
            if Int(thisMode.ioFlags) & kDisplayModeInterlacedFlag != 0 {
                outputString += "i"
            }

			// add information about the scaling of the mode (is it HiDPI?)
			if thisMode.width != thisMode.pixelWidth {
				outputString += " @ \(thisMode.pixelWidth/thisMode.width)x"
			} else if onlyHidpiModes {
                continue
            }

            // add refresh rate, if supported
            if thisMode.refreshRate != 0 {
                outputString += " (\(thisMode.refreshRate) Hz)"
            }

			// deal with potentially unsafe modes
            if !thisMode.isUsableForDesktopGUI() || (Int(thisMode.ioFlags) & kDisplayModeNotPresetFlag != 0) {
				if onlyUsableModes {
					continue
				} else {
					outputString += " ⚠️"
				}
			}
			
			let menuItem = NSMenuItem(title: outputString, action: #selector(changeDisplayMode), keyEquivalent: "")
			menuItem.representedObject = thisMode as CGDisplayMode
			menuItem.image = #imageLiteral(resourceName: "statusIcon")
			
			// if this mode is the one in use, select it
			if thisMode == CGDisplayCopyDisplayMode(getCurrentDisplay())! {
                menuItem.state = .on
			}
            let newItem = (outputString, thisMode.ioFlags)
            let alreadyExists = safeModeList.contains(where: {$0.0 == newItem.0 && $0.1 == newItem.1})

            let modeIsSafe = (Int(thisMode.ioFlags) & (kDisplayModeSafeFlag + kDisplayModeValidFlag)) != 0

            if !alreadyExists && modeIsSafe {
                safeModeList.append(newItem)
                menuIndex += 1
                menu.insertItem(menuItem, at: menuIndex)
//                print(outputString + "; \(String(format:"%X", thisMode.ioFlags))")

            }
		}
//        print("modes: \(modes.count), unique: \(safeModeList.count)")
	}
	
	@objc func toggleShownDisplayModes(sender: NSMenuItem) {
		// toggle state
		if sender.state == .on {
			sender.state = .off
            onlySafeModes = false
		} else {
			sender.state = .on
            onlySafeModes = true
		}
        rebuildMenu()
	}

    @objc func toggleShownHidpiModes(sender: NSMenuItem) {
		// toggle state
		if sender.state == .on {
			sender.state = .off
            onlyHidpiModes = false
		} else {
			sender.state = .on
            onlyHidpiModes = true
		}
        rebuildMenu()
	}

	@objc func changeDisplayMode(sender: NSMenuItem) {
		let mode = sender.representedObject as! CGDisplayMode
		let configToken = UnsafeMutablePointer<CGDisplayConfigRef?>.allocate(capacity: 1)
		CGBeginDisplayConfiguration(configToken)
		CGConfigureDisplayWithDisplayMode(configToken.pointee!, getCurrentDisplay(), mode, nil)
		CGCompleteDisplayConfiguration(configToken.pointee!, .permanently)
        updateActiveDisplayMode(on: menu)
        configToken.deallocate()
	}
	
	func updateActiveDisplayMode(on menu: NSMenu) {
		let mode = CGDisplayCopyDisplayMode(getCurrentDisplay())!
		for i in menu.items {

            // if we hit the separator then we're out of modes to check
            if i.isSeparatorItem {
                break;
            // check if this is the first menu item
            } else if i.action == nil {
                continue;
            }

            // swift currently can't typecast from Any? to CG types
            // so the only option is to forcibly cast
            if i.representedObject as! CGDisplayMode == mode {
                getCurrentDisplayMode().state = .off
                i.state = .on
                return
            }
		}
	}

    func getCurrentDisplayMode() -> NSMenuItem {
        var thisItem: NSMenuItem?
        var i = 0
        repeat {
            thisItem = menu.items[i]
            if thisItem!.state == .on {
                break
            }
            i += 1
        } while (!(thisItem!.isSeparatorItem))

        // should never be nil
        return thisItem!
    }

    func rebuildMenu() {
        menu.removeAllItems()
        buildMenu()
    }

    func buildMenu() {
        // Get all display modes
        displayModes = getAllDisplayModes()

        //- Build Menu -
        let titleItem = NSMenuItem(title: "Display modes:", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        //-------------- add display modes to menu
        showDisplayModes(displayModes, onlyUsableModes: onlySafeModes)
        //--------------
        menu.addItem(NSMenuItem.separator())
        //--------------
        let showModesItem = NSMenuItem(title: "Show only safe modes", action: #selector(toggleShownDisplayModes), keyEquivalent: "")
        showModesItem.state = (onlySafeModes ? .on : .off)
        menu.addItem(showModesItem)
        //--------------
        let showHidpiItem = NSMenuItem(title: "Show only HiDPI modes", action: #selector(toggleShownHidpiModes), keyEquivalent: "")
        showHidpiItem.state = (onlyHidpiModes ? .on : .off)
        menu.addItem(showHidpiItem)
        //--------------
        menu.addItem(NSMenuItem.separator())
        //--------------
        menu.addItem(withTitle: "Quit Exhibition", action: #selector(NSApplication.shared.terminate(_:)), keyEquivalent: "")
        //--------------
    }

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Set icon
		let icon = #imageLiteral(resourceName: "statusIcon")
		icon.isTemplate = true
		statusItem.image = icon
		statusItem.highlightMode = true
		statusItem.menu = menu
        buildMenu()
		
		// Make observer for if user changes display in System Preferences
		NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: nil, using: { _ in
			self.updateActiveDisplayMode(on: self.menu)
		})

        // remake the menu if we switch to another display
        // this is also called when the app starts up for the first time
        NotificationCenter.default.addObserver(forName: NSWindow.didChangeScreenNotification, object: nil, queue: nil, using: { _ in
            self.rebuildMenu()
        })
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}
}
