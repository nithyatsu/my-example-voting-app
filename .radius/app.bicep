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
  name: 'postgres'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'docker-compose.yml#L64'
    size: 'S'
    database: 'postgres'
    username: 'postgres'
    password: postgresPassword
  }
}

resource redisCache 'Radius.Data/redisCaches@2025-08-01-preview' = {
  name: 'redis'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'docker-compose.yml#L54'
    size: 'S'
  }
}

resource resultImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'result-image'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'result/Dockerfile#L1'
    tag: '1831c4d'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//result?ref=1831c4da061eb46464c25e723f5c91dda0d40f96'
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
    tag: '1831c4d'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//vote?ref=1831c4da061eb46464c25e723f5c91dda0d40f96'
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
    tag: '1831c4d'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//worker?ref=1831c4da061eb46464c25e723f5c91dda0d40f96'
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
    codeReference: 'result/server.js#L20'
    connections: {
      postgresdb: {
        source: postgresDb.id
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
    application: votingApp.id
    codeReference: 'vote/app.py#L19'
    connections: {
      rediscache: {
        source: redisCache.id
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
    application: votingApp.id
    codeReference: 'worker/Program.cs#L15'
    connections: {
      postgresdb: {
        source: postgresDb.id
      }
      rediscache: {
        source: redisCache.id
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
  name: 'result'
  properties: {
    environment: environment
    application: votingApp.id
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
          containerPort: 80
        }
      }
    ]
  }
}

resource voteRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'vote'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'docker-compose.yml#L6'
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
