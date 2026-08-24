extension radius

param environment string

@description('Username for the OCI registry the containerImages recipe pushes to.')
@secure()
param registryUsername string

@description('Password or token for the OCI registry the containerImages recipe pushes to.')
@secure()
param registryPassword string

@description('Administrator password for PostgreSQL.')
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
    database: 'postgres'
    size: 'S'
    username: 'postgres'
    password: postgresPassword
  }
}

resource redisCache 'Radius.Data/redisCaches@2025-08-01-preview' = {
  name: 'redis'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'vote/app.py#L19'
    size: 'S'
  }
}

resource registryCreds 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'radius-ghcr-registry-creds'
  properties: {
    environment: environment
    application: votingApp.id
    data: {
      password: {
        value: registryPassword
      }
      username: {
        value: registryUsername
      }
    }
  }
}

resource resultImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'result-image'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'result/Dockerfile'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//result?ref=e2e1a9d0cefd08696b5f72cdd20d3bcf9825a3ef'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource voteImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'vote-image'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'vote/Dockerfile'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//vote?ref=e2e1a9d0cefd08696b5f72cdd20d3bcf9825a3ef'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource workerImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'worker-image'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'worker/Dockerfile'
    build: {
      source: 'git::https://github.com/nithyatsu/my-example-voting-app.git//worker?ref=e2e1a9d0cefd08696b5f72cdd20d3bcf9825a3ef'
      platforms: [
        'linux/amd64'
      ]
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource resultContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'result'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'result/Dockerfile'
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
      }
    }
  }
}

resource voteContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'vote'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'vote/Dockerfile'
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
      }
    }
  }
}

resource workerContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'worker'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'worker/Dockerfile'
    containers: {
      worker: {
        image: workerImage.properties.imageReference
      }
    }
    connections: {
      postgresdb: {
        source: postgresDb.id
      }
      rediscache: {
        source: redisCache.id
      }
    }
  }
}

resource resultRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'result-route'
  properties: {
    environment: environment
    application: votingApp.id
    codeReference: 'k8s-specifications/result-service.yaml#L1'
    kind: 'HTTP'
    rules: [
      {
        matches: [
          {
            httpPath: '/results'
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
    application: votingApp.id
    codeReference: 'k8s-specifications/vote-service.yaml#L1'
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
