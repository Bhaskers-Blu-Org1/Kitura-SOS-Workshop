# Kitura SOS Workshop

<p align="center">
<img src="https://www.ibm.com/cloud-computing/bluemix/sites/default/files/assets/page/catalog-swift.svg" width="120" alt="Kitura Bird">
</p>

<p align="center">
<a href= "http://swift-at-ibm-slack.mybluemix.net/">
    <img src="http://swift-at-ibm-slack.mybluemix.net/badge.svg"  alt="Slack">
</a>
</p>

## Workshop Table of Contents:

1. [Getting Started](./01-GettingStarted.md)
2. [Setting up the Server](./02-ServerSetUp.md)
3. [Setting up the Dashboard](./03-DashboardSetUp.md)
4. [Setting up the iOS Client](./04-iOSSetUp.md)
5. **[Handling Status Reports and Disasters](./05-StatusReportsAndDisasters.md)**
6. [Setting up OpenAPI and REST API functionality](./06-OpenAndRESTAPI.md)
7. [Build your app into a Docker image and deploy it on Kubernetes](./07-DockerAndKubernetes.md)
8. [Enable monitoring through Prometheus/Grafana](./08-PrometheusAndGrafana.md)

# Handling Status Reports and Disasters

## Status Reports

Now, go back to your server project. Open `MyWebSocketService.swift` and go to the `parse:` function. Add this conditional decode logic at the bottom of the function:

```swift
if let person = try? JSONDecoder().decode(Person.self, from: data) {
    Log.info("person status reported: \(person.name) is \(person.status.status)")
    reportStatus(for: person)
}
```

Next, beneath this function, add the following code to `reportStatus` whenever a connection confirms a `Person` object:

```swift
connectedPeople = connectedPeople.filter { $0.id != person.id }
connectedPeople.append(person)
guard let dashboard = dashboardConnection else {
    return Log.error("dashboard is not currently registered with server")
}
let dashboardConnection = allConnections.filter { $0.id == dashboard.dashboardID }.first
do {
    dashboardConnection?.send(message: try JSONEncoder().encode(person))
} catch let error {
    Log.error("encountered error reporting status for person \(person.id): \(error.localizedDescription)")
}
```

By now, you are handling the registration of a person, storing their status, and sending that registration onto the dashboard. Open your macOS dashboard application, and open `DisasterSocketClientDashboard.swift`. Add this decode logic to the `parse:` function:

```swift
if let person = try? JSONDecoder().decode(Person.self, from: data) {
    print("received status of person: \(person.id)")
    delegate?.statusReported(client: self, person: person)
}
```

Now, open `ViewController.swift` located in your dashboard project and find the delegate function for `statusReported:`. Add the following code inside this function:

```swift
annotationProcessingQueue.sync {
  let coordinate = CLLocationCoordinate2D(latitude: person.coordinate.latitude, longitude: person.coordinate.longitude)
  if person.status.status == "Unreported" {
    let newAnnotation = UnreportedPersonAnnotation(coordinate: coordinate, person: person)
    self.annotations.append(newAnnotation)
    drop(newAnnotation)
  }
  else if person.status.status == "Safe" {
    removeDuplicateAnnotations(for: person)
    let newAnnotation = SafePersonAnnotation(coordinate: coordinate, person: person)
    self.annotations.append(newAnnotation)
    drop(newAnnotation)
  }
  else if person.status.status == "Unsafe" {
    removeDuplicateAnnotations(for: person)
    let newAnnotation = UnsafePersonAnnotation(coordinate: coordinate, person: person)
    self.annotations.append(newAnnotation)
    drop(newAnnotation)
  }
}
```

This does a lot of the [MapKit](https://developer.apple.com/documentation/mapkit) work for you, but you can follow the logic to see what happens. For now, you are only really going to handle an unreported status. Lastly, add the following code inside your `removeDuplicateAnnotations:` function:

```swift
let existingAnnotation = self.annotations.filter { $0.person?.id == person.id }
self.annotations = self.annotations.filter { $0.person?.id != person.id }
DispatchQueue.main.async {
    self.mapView?.removeAnnotations(existingAnnotation)
}
```

Restart your server, run your dashboard, connect, then run your iOS client and connect. Without any breakpoints, you should see a pin drop for the person that registered after that person confirms their name. You are now ready to handle a disaster!!

## Disasters

You're going to trigger a disaster from your dashboard, and the server will notify each iOS device connected to it. As each device reports its status, the dashboard will update asynchronously with the statuses as they come in.

First, open `DisasterSocketClientDashboard.swift` on your dashboard. Add the following code underneath the `confirm:Dashboard` function:

```swift
public func simulate(_ disaster: Disaster) {
    do {
        try disasterSocket?.write(data: JSONEncoder().encode(disaster))
    } catch let error {
        delegate?.clientErrorOccurred(client: self, error: error)
    }
}
```

Now you have the ability to report a disaster. Scroll `vcConfDisasterName:` function in `ViewController.swift` of your dashboard project and add the following code after `dismiss()` is called:

```swift
guard let location = mapView?.userLocation.coordinate else {
    return
}
let disaster = Disaster(coordinate: Coordinate(latitude: location.latitude, longitude: location.longitude), name: name)
disasterClient.simulate(disaster)
```

Now your dashboard is wired up. Next open your server, and open up `MyWebSocketService.swift`. Add the following code to the bottom of your `parse:Data` function:

```swift
else if let disaster = try? JSONDecoder().decode(Disaster.self, from: data) {
        Log.info("disaster occurred! \(disaster.name) at (\(disaster.coordinate.latitude), \(disaster.coordinate.longitude))")
    notifyDevices(of: disaster)
}
```

By now, your `parse` function should effectively be looking for three different types of `Data`, all thanks to `Codable`. Now, scroll to the `notifyDevices` function, and add the following code:

```swift
guard let dashboardConnection = dashboardConnection else {
    return Log.error("no registered dashboard connection")
}
let connectedDevices = allConnections.filter { $0.id != dashboardConnection.dashboardID }
for device in connectedDevices {
    do {
        device.send(message: try JSONEncoder().encode(disaster))
    } catch let error {
        Log.error("Encountered error reporting disaster to device \(device.id): \(error.localizedDescription)")
    }
}
```

This loops through all of the existing connections to iOS devices, and sends a message to each of them with the disaster type. All that's left is to handle this on your device!

Open your iOS client project, and open `DisasterSocketClientiOS.swift`. Add this code to the bottom of your `parse:Data` function:

```swift
else if let disaster = try? JSONDecoder().decode(Disaster.self, from: data) {
    print("disaster reported: \(disaster.name)")
    delegate?.clientReceivedDisaster(client: self, disaster: disaster)
}
```

Now, open `ViewController.swift` in your iOS project and add the following code inside the `clientReceivedDisaster:` function:

```swift
DispatchQueue.main.async {
  guard var person = self.currentPerson else {
    print("no current person listed")
  return
  }
  let alert = UIAlertController(title: "DISASTER!!!", message: "Oh no! \(disaster.name) in your area!! Are you safe?", preferredStyle: .alert)
  let safeAction = UIAlertAction(title: "Yes", style: .default, handler: { action in
    person.status.status = "Safe"
    client.reportStatus(for: person)
    })
   let unsafeAction = UIAlertAction(title: "No", style: .destructive, handler: { action in
     person.status.status = "Unsafe"
     client.reportStatus(for: person)
    })
    alert.addAction(safeAction)
    alert.addAction(unsafeAction)
    self.present(alert, animated: true, completion: nil)
  }
```

Save everything. You are now ready to test the entire flow!

Follow these steps in order:

1. Run your server
2. Run your dashboard
3. Connect your dashboard
4. Run your iOS client
5. Connect your iOS client
6. Confirm the status of your iOS client on your dashboard
7. Report a disaster from the dashboard
8. Respond to the disaster on your iOS client
9. Watch the status report on the dashboard

# Next Steps

Continue to the [next page](./06-OpenAndRESTAPI.md) to learn how to use Open API and REST API.
