.PHONY: all build test app run clean

all: app test

build:
	swift build

test:
	swift run BubombTests

app:
	bash scripts/build_app.sh

run:
	bash scripts/run.sh

clean:
	rm -rf .build Bubomb.app
