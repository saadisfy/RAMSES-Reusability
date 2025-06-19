#!/bin/bash
PrintSuccess() { echo -e "\033[0;32m$1\033[0m"; }
PrintWarn() { echo -e "\033[0;33m$1\033[0m"; }
PrintError() { echo -e "\033[0;31m$1\033[0m"; }

# Check if RAMSES-SEFA system is running
PrintWarn "Checking if RAMSES-SEFA system is running..."
if ! docker ps --format "table {{.Names}}" | grep -q "ramses-knowledge"; then
    PrintError "RAMSES-SEFA system doesn't appear to be running!"
    PrintError "Please run SETUP_ICSE_PERSONALE.sh first to start the system."
    exit 1
fi

if ! docker ps --format "table {{.Names}}" | grep -q "sefa-eureka"; then
    PrintError "SEFA services don't appear to be running!"
    PrintError "Please run SETUP_ICSE_PERSONALE.sh first to start the system."
    exit 1
fi

PrintSuccess "RAMSES-SEFA system is running!"
echo

# Detect architecture
PrintWarn "Supported architecture are 'arm64' and 'amd64'. Using 'amd64' as default option"
ARCH="amd64"
PrintWarn "Running simulation with selected architecture: ${ARCH}"
echo

# Check for existing simulation containers and offer to stop them
existing_sims=$(docker ps --format "table {{.Names}}" | grep "simulation-scenario" || true)
if [ ! -z "$existing_sims" ]; then
    PrintWarn "Found running simulation containers:"
    echo "$existing_sims"
    echo
    PrintWarn "Do you want to stop existing simulations? (y/n):"
    read stop_existing
    if [[ $stop_existing =~ ^[Yy]$ ]]; then
        PrintSuccess "Stopping existing simulation containers..."
        docker ps --format "{{.Names}}" | grep "simulation-scenario" | xargs -r docker stop
        docker ps -a --format "{{.Names}}" | grep "simulation-scenario" | xargs -r docker rm
        echo
    fi
fi

# Simulation scenario selection
# NOTE: These scenarios are actually the rest-client application (from ramses-sefa-SAS)
# configured with different environment variables to trigger specific behaviors:
# - PerformanceFakerService: Controls performance degradation
# - BenchmarksChangerService: Controls implementation changes  
# - FailureInjectionService: Controls failure injection
# - AdaptationController: Controls RAMSES interaction
# Source code available in: ramses-sefa-SAS/managed-system/rest-client/
echo; PrintWarn "Choose a simulation scenario to run:"; echo
PrintWarn "1: addInstance     - Injects failures to trigger instance scaling (5min trial)"
PrintWarn "2: changeImplementation - Changes service implementation via RAMSES"
PrintWarn "3: changeLBWeights - Modifies load balancer weights via configuration"
PrintWarn "4: shutdownInstance - Shuts down instances to test failure recovery"
echo
PrintWarn "5: List running simulations"
PrintWarn "6: Stop all simulations"
echo

echo "Insert the number of the scenario you want (1-6) or press anything else to exit:"
read userInput

case $userInput in
    1|2|3|4)
        PrintSuccess "You chose to simulate scenario $userInput."
        PrintSuccess "Pulling simulation container..."
        docker pull giamburrasca/scenario$userInput:$ARCH
        
        # Check if container with same name exists and remove it
        if docker ps -a --format "{{.Names}}" | grep -q "simulation-scenario-$userInput"; then
            PrintWarn "Removing existing simulation-scenario-$userInput container..."
            docker rm -f simulation-scenario-$userInput
        fi
        
        PrintSuccess "Starting simulation scenario $userInput..."
        docker run -P --name simulation-scenario-$userInput -d --network ramses-sas-net giamburrasca/scenario$userInput:$ARCH
        echo
        PrintSuccess "Simulation scenario $userInput started successfully!"
        PrintWarn "Monitor the RAMSES dashboard to see the adaptation in action."
        PrintWarn "Container name: simulation-scenario-$userInput"
        ;;
    5)
        PrintSuccess "Running simulation containers:"
        running_sims=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "simulation-scenario" || echo "No simulations currently running")
        echo "$running_sims"
        ;;
    6)
        PrintWarn "Stopping all simulation containers..."
        stopped_count=$(docker ps --format "{{.Names}}" | grep "simulation-scenario" | wc -l)
        if [ "$stopped_count" -gt 0 ]; then
            docker ps --format "{{.Names}}" | grep "simulation-scenario" | xargs docker stop
            docker ps -a --format "{{.Names}}" | grep "simulation-scenario" | xargs docker rm
            PrintSuccess "Stopped and removed $stopped_count simulation containers."
        else
            PrintWarn "No simulation containers are currently running."
        fi
        ;;
    *)
        PrintSuccess "Enjoy RAMSES!"
        exit 0
        ;;
esac

echo
PrintWarn "You can run this simulation script again to start additional scenarios."
PrintWarn "Use option 5 to list running simulations or option 6 to stop all." 