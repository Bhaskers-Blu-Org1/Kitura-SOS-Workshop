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
5. [Handling Status Reports and Disasters](./05-StatusReportsAndDisasters.md)
6. **[Setting up OpenAPI and REST API functionality](./06-OpenAndRESTAPI.md)**
7. [Build your app into a Docker image and deploy it on Kubernetes](./07-DockerAndKubernetes.md)
8. [Enable monitoring through Prometheus/Grafana](./08-PrometheusAndGrafana.md)

# Setting up OpenAPI and REST API functionality

## Try out OpenAPI in Kitura

With your Kitura server still running, open [http://localhost:8080/openapi/ui](http://localhost:8080/openapi/ui) and view SwaggerUI, a popular API development tool. SwaggerUI shows all the REST endpoints defined on your server.

You will see one route defined: the GET `/health` route. Click on the route to expand it, then click "Try it out!" to query the API from inside SwaggerUI.

You should see a Response Body in JSON format, like:

```
{
  "status": "UP",
  "details": [],
  "timestamp": "2019-09-07T14:38:07+0000"
}
```

and a Response Code of 200.

Congratulations, you have used SwaggerUI to query a REST API!

## Add Support for handling a `GET` request on `/users`

REST APIs typically consist of an HTTP request using a verb such as `POST`, `PUT`, `GET` or `DELETE` along with a URL and an optional data payload. The server then handles the request and responds with an optional data payload.

A request to load all of the stored data typically consists of a `GET` request with no data, which the server then handles and responds with an array of all the data in the store.

1. In `Application.swift`, add a `getAllHandler()` function to the `App` class that responds with an array of all the connected people as an array:
  ```swift
	func getAllHandler(completion: ([Person]?, RequestError?) -> Void) {
		return completion(self.disasterService.connectedPeople, nil)
	}
  ```

2. Register a handler for a `GET` request on `/users` that calls your new function.  Add the following at the end of the `postInit()`:  
   ```swift
	router.get("/users", handler: getAllHandler)
   ```

3. Restart your server and refresh SwaggerUI again and view your new GET route. Clicking "Try it out!" will return the empty array (`[]`), because there are no current connections to the server. Experiment with connecting to the server and using your GET method to see all the connections. REST APIs are easy!

## Add Support for handling a `GET` request on `/users:id`

For this request, we want to return all the info on a specific user by using their unique id

1. Register a handler for a `GET` request on `/users` that loads the data.  Add the following into the `postInit()` function:  
   ```swift
	router.get("/users", handler: getOneHandler)
   ```
2. Implement a public `getOnePerson` function in `MyWebSocketService.swift`, that returns a Person object, beneath your `getAllConnections` function

  ```swift
  public func getOnePerson(id: String) -> Person? {

        for person in connectedPeople {
            if person.id == id {
                return person
            }
        }
        return nil
    }
  ```
3.  Implement the `getOneHandler()` that takes a String that is the person's specific id and responds with all the data associated with that user.  Add the following as a function in the App class:

  ```swift
  func getOneHandler(id: String, completion:(Person?, RequestError?) -> Void ) {
        return completion(disasterService.getOnePerson(id: id), nil)
    }
  ```
4. Restart your server and refresh SwaggerUI again and view your new GET route.

## Add Support for handling a `GET` request on `/stats`

For this request, we want to find several statistics about the server. We will display:

* The start time of the server
* The current time
* The percentage of connected users reported as safe
* The percentage of connected users reported as unsafe
* The percentage of connected users reported as unreported

1. Register a handler for a `GET` request on `/stats` that loads the data  
   Add the following into the `postInit()` function:  
   ```swift
	router.get("/stats", handler: getStatsHandler)
   ```
2. Create a global variable in `Application.swift` outside the scope of the App class that stores the time of the server when launched:
   ```swift
   public var startDate = String()
   ```
   Then at the start of the `postInit()` method, add:
   ```swift
   let date: Date = Date()
   let dateFormatter = DateFormatter()
   dateFormatter.dateFormat = "yyyy-MM-dd'T 'HH:mm:ss"
   startDate = dateFormatter.string(from: date)
   ```

3. Create a Codable structure in `Models.swift` that holds all the values we need for our statistics:

```swift
struct StatsStructure: Codable {
    var safePercentage: Double
    var unsafePercentage: Double
    var unreportedPercentage: Double
    var startTime: String
    var currentTime: String
}
```

4. Implement a public `getStats` function in `MyWebSocketService.swift`, that returns all the statistics we need for our server:

  ```swift
  public func getStats() -> StatsStructure? {

    let date: Date = Date()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T 'HH:mm:ss"
    let currentDate = dateFormatter.string(from: date)

    var currentStatsStructure = StatsStructure(safePercentage: 0.0, unsafePercentage: 0.0, unreportedPercentage: 0.0, startTime: startDate, currentTime: currentDate)

    if connectedPeople.count>0 {

      let percentNumber = 100/Double(connectedPeople.count)
      var safeNumber = 0.0
      var unsafeNumber = 0.0
      var unreportedNumber = 0.0

      for person in connectedPeople {

        if person.status.status == "Safe" {
          safeNumber += 1.0
        }

        else if person.status.status == "Unsafe" {
          unsafeNumber += 1.0
        }

        else {
          unreportedNumber += 1.0
        }

        }

        let percentageSafe = percentNumber*safeNumber
        currentStatsStructure.safePercentage = percentageSafe

        let percentageUnsafe = percentNumber*unsafeNumber
        currentStatsStructure.unsafePercentage = percentageUnsafe

        let percentageUnreported = percentNumber*safeNumber
        currentStatsStructure.unreportedPercentage = percentageUnreported

        }

        return currentStatsStructure

    }
  ```
5.  Implement a `getStatsHandler()` that responds with all the data.  Add the following as a function in the App class:

  ```swift
  func getStatsHandler(completion: (StatsStructure?, RequestError?) -> Void ) {
        return completion(disasterService.getStats(), nil)
    }
  ```
6. Restart your server and refresh SwaggerUI again and view your new GET route.

# Next Steps

Continue to the [next page](./07-DockerAndKubernetes.md) to learn how to use Docker and Kubernetes.