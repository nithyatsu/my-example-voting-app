extension radius

param environment string

@secure()
param postgresPassword string

resource votingApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'my-example-voting-app'
  properties: {
    environment: environment
  }
}

resource postgresDb 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'db'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'worker/Program.cs#L19'
    password: postgresPassword
    size: 'S'
    username: 'postgres'
  }
}

resource redisCache 'Radius.Data/redisCaches@2025-08-01-preview' = {
  name: 'redis'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'vote/app.py#L21'
    size: 'S'
  }
}

resource resultImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'result-image'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'result/Dockerfile#L1'
    tag: '49edfafb-result'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//result?ref=49edfafb3b0c1100d0ed0280c2c88ef3fd881f35'
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
    application: votingApp.id
    codeReference: 'vote/Dockerfile#L1'
    tag: '49edfafb-vote'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//vote?ref=49edfafb3b0c1100d0ed0280c2c88ef3fd881f35'
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
    application: votingApp.id
    codeReference: 'worker/Dockerfile#L1'
    tag: '49edfafb-worker'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//worker?ref=49edfafb3b0c1100d0ed0280c2c88ef3fd881f35'
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
    application: votingApp.id
    codeReference: 'result/Dockerfile#L1'
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
    connections: {
      postgresdb: {
        source: postgresDb.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource voteContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'vote'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'vote/Dockerfile#L1'
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
    connections: {
      rediscache: {
        source: redisCache.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource workerContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'worker'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'worker/Dockerfile#L1'
    containers: {
      worker: {
        image: workerImage.properties.imageReference
      }
    }
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
  }
}

resource resultRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'result-route'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'docker-compose.yml#L36'
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
          containerPort: 80
        }
      }
    ]
  }
}

resource voteRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'vote-route'
  properties: {
    environment: environment
    application: votingApp.id
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
          containerPort: 80
        }
      }
    ]
  }
}
