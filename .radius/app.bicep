extension radius

param environment string

@secure()
param postgreSqlPassword string

resource myExampleVotingApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'my-example-voting-app'
  properties: {
    environment: environment
  }
}

resource postgresDb 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'db'
  properties: {
    environment: environment
    application: myExampleVotingApp.id
    codeReference: 'docker-compose.yml#L64'
    database: 'postgres'
    password: postgreSqlPassword
    size: 'S'
    username: 'postgres'
  }
}

resource redisCache 'Radius.Data/redisCaches@2025-08-01-preview' = {
  name: 'redis'
  properties: {
    environment: environment
    application: myExampleVotingApp.id
    codeReference: 'vote/app.py#L19'
    size: 'S'
  }
}

resource resultImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'result-image'
  properties: {
    environment: environment
    application: myExampleVotingApp.id
    codeReference: 'result/Dockerfile#L1'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//result?ref=63e9150ca17af4ed05880d4245e486481f73fcb4'
      platforms: [
        'linux/amd64'
      ]
    }
  }
}

resource voteImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'vote-image'
  properties: {
    environment: environment
    application: myExampleVotingApp.id
    codeReference: 'vote/Dockerfile#L2'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//vote?ref=63e9150ca17af4ed05880d4245e486481f73fcb4'
      platforms: [
        'linux/amd64'
      ]
    }
  }
}

resource workerImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'worker-image'
  properties: {
    environment: environment
    application: myExampleVotingApp.id
    codeReference: 'worker/Dockerfile#L11'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//worker?ref=63e9150ca17af4ed05880d4245e486481f73fcb4'
      platforms: [
        'linux/amd64'
      ]
    }
  }
}

resource resultContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'result'
  properties: {
    environment: environment
    application: myExampleVotingApp.id
    codeReference: 'result/server.js#L20'
    connections: {
      postgresdb: {
        source: postgresDb.id
        disableDefaultEnvVars: true
      }
    }
    containers: {
      result: {
        image: resultImage.properties.imageReference
        ports: {
          web: {
            containerPort: 80
          }
        }
      }
    }
  }
}

resource voteContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'vote'
  properties: {
    environment: environment
    application: myExampleVotingApp.id
    codeReference: 'vote/app.py#L13'
    connections: {
      rediscache: {
        source: redisCache.id
        disableDefaultEnvVars: true
      }
    }
    containers: {
      vote: {
        image: voteImage.properties.imageReference
        ports: {
          web: {
            containerPort: 80
          }
        }
      }
    }
  }
}

resource workerContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'worker'
  properties: {
    environment: environment
    application: myExampleVotingApp.id
    codeReference: 'worker/Program.cs#L15'
    connections: {
      postgresdb: {
        source: postgresDb.id
        disableDefaultEnvVars: true
      }
      rediscache: {
        source: redisCache.id
        disableDefaultEnvVars: true
      }
    }
    containers: {
      worker: {
        image: workerImage.properties.imageReference
      }
    }
  }
}

resource resultRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'result-route'
  properties: {
    environment: environment
    application: myExampleVotingApp.id
    codeReference: 'docker-compose.yml#L27'
    kind: 'HTTP'
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: resultContainer.id
          containerName: 'result'
          containerPort: resultContainer.properties.containers.result.ports.web.containerPort
        }
      }
    ]
  }
}

resource voteRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'vote-route'
  properties: {
    environment: environment
    application: myExampleVotingApp.id
    codeReference: 'docker-compose.yml#L21'
    kind: 'HTTP'
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: voteContainer.id
          containerName: 'vote'
          containerPort: voteContainer.properties.containers.vote.ports.web.containerPort
        }
      }
    ]
  }
}
