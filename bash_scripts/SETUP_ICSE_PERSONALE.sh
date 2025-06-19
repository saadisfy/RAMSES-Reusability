#!/bin/bash
PrintSuccess() { echo -e "\033[0;32m$1\033[0m"; }
PrintWarn() { echo -e "\033[0;33m$1\033[0m"; }
PrintError() { echo -e "\033[0;31m$1\033[0m"; }

if [[("${GITHUB_OAUTH}" = "") || ("${GITHUB_REPOSITORY_URL}" = "")]]; then
  PrintError "Env var GITHUB_OAUTH and GITHUB_REPOSITORY_URL must be set!"
  exit 1
fi

PrintWarn "Supported architecture are 'arm64' and 'amd64'. Using 'amd64' as default option"
PrintWarn "Some components are not supported for amd64, so they will be emulated in arm64"

ARCH="amd64"
PrintWarn "Running script with selceted architecture: ${ARCH}"
sleep 3


##### Network #####
docker network rm ramses-sas-net
PrintSuccess "-- Network Removed --"
PrintSuccess "Creating new Docker network called 'ramses-sas-net'"
docker network create ramses-sas-net
echo

##### DOCKER SOCKET EXPOSURE (for sefa-instances-manager) #####
PrintWarn "MANUAL STEP REQUIRED FOR WINDOWS DOCKER DESKTOP:"
PrintWarn "1. Open Docker Desktop Settings"
PrintWarn "2. Go to 'Advanced' or 'General' settings"
PrintWarn "3. Enable 'Expose daemon on tcp://localhost:2375 without TLS'"
PrintWarn "4. Apply & Restart Docker Desktop"
PrintWarn "5. Then run this script again"
echo
PrintWarn "Checking if Docker API is available on port 2375..."
if curl -s http://localhost:2375/version > /dev/null 2>&1; then
    PrintSuccess "Docker API is available on port 2375!"
else
    PrintError "Docker API is NOT available on port 2375"
    PrintError "Please enable TCP exposure in Docker Desktop settings first"
    exit 1
fi
echo
sleep 3

##### MYSQL #####
PrintSuccess "Setting up MySQL Server"
docker pull giamburrasca/mysql:$ARCH
docker run -P --name mysql -d --network ramses-sas-net giamburrasca/mysql:$ARCH
echo
sleep 10

PrintSuccess "Setting up Netflix Eureka Server"
docker pull giamburrasca/sefa-eureka:arm64
docker run -P --name sefa-eureka -d --network ramses-sas-net giamburrasca/sefa-eureka:arm64
echo
sleep 15

PrintSuccess "Setting up Spring Config Server"
docker pull giamburrasca/sefa-configserver:arm64
docker run -P --name sefa-configserver -e GITHUB_REPOSITORY_URL=$GITHUB_REPOSITORY_URL -d --network ramses-sas-net giamburrasca/sefa-configserver:arm64
echo
sleep 90

##### PROBE (must start before ramses-knowledge) #####
echo; PrintSuccess "Setting up probe!"; echo
PrintSuccess "Pulling sefa-probe"
docker pull giamburrasca/sefa-probe:$ARCH
docker run -P --name sefa-probe -d --network ramses-sas-net giamburrasca/sefa-probe:$ARCH
echo
sleep 15

##### SEFA SERVICES (Must start BEFORE ramses-knowledge) #####
echo; PrintSuccess "Setting up SEFA Services (managed system)!"; echo

declare -a arr=("sefa-restaurant-service"
                "sefa-ordering-service"
                "sefa-payment-proxy-1-service"
                "sefa-delivery-proxy-1-service"
		            "sefa-web-service"
                "sefa-api-gateway"
                )
for i in "${arr[@]}"
do
   PrintSuccess "Setting up $i"
   docker pull giamburrasca/$i:$ARCH
   docker run -P --name $i -d --network ramses-sas-net giamburrasca/$i:$ARCH
   echo
   sleep 5
done

PrintSuccess "Waiting for SEFA services to register in Eureka..."
sleep 30

##### INSTANCES MANAGER (requires Docker socket exposed over HTTP) #####
# NOTE: The instances-manager Java code is hardcoded to use TCP connection to host.docker.internal:2375
# and cannot use Unix sockets. We need to expose Docker socket over HTTP as documented in
# ExposeDockerSocketOnHTTP.txt. This requires --add-host=host.docker.internal:host-gateway
# so the container can reach the host's Docker daemon exposed on port 2375.
PrintSuccess "Pulling sefa-instances-manager"
docker pull giamburrasca/sefa-instances-manager:$ARCH
docker run -P --name sefa-instances-manager --add-host=host.docker.internal:host-gateway -d --network ramses-sas-net giamburrasca/sefa-instances-manager:$ARCH
echo
sleep 10

##### RAMSES KNOWLEDGE (after SEFA services are registered) #####
PrintSuccess "Setting up RAMSES Knowledge"
docker pull giamburrasca/ramses-knowledge:$ARCH
docker run -P --name ramses-knowledge -d --network ramses-sas-net giamburrasca/ramses-knowledge:$ARCH
sleep 15

declare -a extra=("sefa-payment-proxy-2-service"
                  "sefa-delivery-proxy-2-service"
                  "sefa-payment-proxy-3-service"
                  "sefa-delivery-proxy-3-service"
                  )
for i in "${extra[@]}"
do
   PrintSuccess "Pulling $i"
   docker pull giamburrasca/$i:$ARCH
   echo
   sleep 1
done


declare -a ramsesarr=("ramses-analyse" "ramses-execute" "ramses-monitor" "ramses-dashboard")
for i in "${ramsesarr[@]}"
do
   PrintSuccess "Pulling $i"
   docker pull giamburrasca/$i:$ARCH
   docker run -P --name $i -d --network ramses-sas-net giamburrasca/$i:$ARCH
   echo
   sleep 2
done

declare -a ramsesarr=("ramses-plan")
for i in "${ramsesarr[@]}"
do
   PrintSuccess "Pulling $i"
   docker pull giamburrasca/$i:arm64 #NOTE: the microservice uses libraries based on arm64. Running with tag "amd64" doesn't work
   docker run -P --name $i -d --network ramses-sas-net giamburrasca/$i:arm64
   echo
   sleep 1
done







PrintSuccess "Pulling sefa-config-manager"
docker pull giamburrasca/sefa-config-manager:$ARCH
docker run -P --name sefa-config-manager -e GITHUB_OAUTH=$GITHUB_OAUTH -e GITHUB_REPOSITORY_URL=$GITHUB_REPOSITORY_URL -d --network ramses-sas-net giamburrasca/sefa-config-manager:$ARCH
echo






echo; PrintSuccess "DONE!"; echo

##### CLEANUP INSTRUCTIONS #####
PrintWarn "RAMSES-SEFA system is now running!"
PrintWarn "To stop everything and cleanup:"
PrintWarn "  docker stop \$(docker ps -q) && docker rm \$(docker ps -aq)"
PrintWarn "  docker network rm ramses-sas-net"
PrintWarn "Note: docker-socat container exposes Docker socket on port 2375"
echo

sleep 3

echo; PrintWarn "RAMSES-SEFA System Setup Complete!"; echo
PrintSuccess "All services are now running and ready for use."
echo
PrintWarn "To run simulation scenarios:"
PrintWarn "  ./run_simulation.sh"
echo
PrintWarn "To access the system:"
PrintWarn "  • RAMSES Dashboard: Check Docker for 'ramses-dashboard' container port"
PrintWarn "  • SEFA Web UI: Check Docker for 'sefa-web-service' container port"
echo
PrintSuccess "Enjoy RAMSES!"

# API_GATEWAY_IP_PORT=localhost:32777 PROBE_URL=http://localhost:32789 DOCKER_ACTUATOR_URL=http://localhost:32791 EUREKA_IP_PORT=localhost:32770 java -jar rest-client-latest.jar
