all: build

build: buildNodeFrontend getCMDDependencies embedFrontend getGoDependencies runUnitTests buildLinux

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
	rm -rf data
	mkdir releases
	cd web && rm build/static/**/*.map

buildLinux:
	CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o releases/golang-url-shortener_linux_amd64 ./cmd/golang-url-shortener

buildMac:
	go build -o releases/golang-url-shortener_darwin_amd64 ./cmd/golang-url-shortener

kill:
	-@killall -INT golang-url-shortener_darwin_amd64  2>/dev/null || true

restart:
	@make kill
	@make buildMac; (if [ "$$?" -eq 0 ]; then (source dev.env; ./releases/golang-url-shortener_darwin_amd64 &); fi)

serve:
	@command -v fswatch --version >/dev/null 2>&1 || { printf >&2 "fswatch is not installed, please run: brew install fswatch\n"; exit 1; }
	@make restart 
	@fswatch -o -e ".*" -i "\\.go$$" --recursive cmd/* internal/* vendor/* | xargs -n1 -I{} make restart || make kill

