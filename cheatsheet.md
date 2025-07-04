# run multiple loadgenerators through compose file
LOAD_GENERATOR_COUNT=3 docker-compose -f docker-compose-loadgen.yml up -d

# run multiple load generators through bash
## First, ensure the network exists
docker network create ramses-sas-net

## Run first load generator
docker run -d \
  --name sefa-load-generator-1 \
  --network ramses-sas-net \
  sbi98/sefa-load-generator:arm64

## Run second load generator
docker run -d \
  --name sefa-load-generator-2 \
  --network ramses-sas-net \
  sbi98/sefa-load-generator:arm64


