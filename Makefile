all: buildNodeFrontend getCMDDependencies embedFrontend getGoDependencies runUnitTests buildProject

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

buildProject:
	rm -rf releases 
	mkdir releases
	gox -output="releases/{{.Dir}}_{{.OS}}_{{.Arch}}/{{.Dir}}" -osarch="linux/amd64 darwin/amd64" -ldflags="-X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagNodeJS=`node --version` -X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagCommit=`git rev-parse HEAD` -X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagNpm=`npm --version` -X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagCompilationTime=`TZ=UTC date +%Y-%m-%dT%H:%M:%S+0000`" ./cmd/golang-url-shortener
	find releases -maxdepth 1 -mindepth 1 -type d -exec cp config/example.yaml {}/config.yaml \;
	find releases -maxdepth 1 -mindepth 1 -type d -exec tar -cvjf {}.tar.bz2 {} \;

buildDockerImage:
	rm -rf docker_releases 
	mkdir docker_releases
	CGO_ENABLED=0 gox -output="docker_releases/{{.Dir}}_{{.OS}}_{{.Arch}}/{{.Dir}}" -osarch="linux/amd64" -ldflags="-X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagNodeJS=`node --version` -X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagCommit=`git rev-parse HEAD` -X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagNpm=`npm --version` -X github.com/endiangroup/golang-url-shortener/internal/util.ldFlagCompilationTime=`TZ=UTC date +%Y-%m-%dT%H:%M:%S+0000`" ./cmd/golang-url-shortener
	docker build -t mxschmitt/golang_url_shortener -f build/Dockerfile.amd64 .
