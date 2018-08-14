all: build

staging: build buildStaging

build: buildNodeFrontend getCMDDependencies embedFrontend getGoDependencies runUnitTests

test: runUnitTests

runUnitTests:
	go test -v ./...

buildNodeFrontend:
	cd web && npm ci
	cd web && npm run build
	cd web && rm build/static/**/*.map

embedFrontend:
	cd internal/handlers/tmpls && esc -o tmpls.go -pkg tmpls -include ^*\.html .
	cd internal/handlers && esc -o static.go -pkg handlers -prefix ../../web/build ../../web/build

getCMDDependencies:
	go get -v github.com/mattn/goveralls
	go get -v github.com/mjibson/esc
	go get -v github.com/mitchellh/gox
	go get -v github.com/golang/dep/cmd/dep

getGoDependencies:
	dep ensure -v

clean:
	rm -rf releases 
	mkdir releases
	cd web && rm build/static/**/*.map

buildStaging:
	gox -output="releases/staging/{{.Dir}}_{{.OS}}_{{.Arch}}/{{.Dir}}" -osarch="linux/amd64" -ldflags="-X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagNodeJS=`node --version` -X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagCommit=`git rev-parse HEAD` -X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagNpm=`npm --version` -X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagCompilationTime=`TZ=UTC date +%Y-%m-%dT%H:%M:%S+0000`" ./cmd/golang-url-shortener
	envsubst < config/staging.yaml > releases/staging/golang-url-shortener_linux_amd64/config.yaml
