.PHONY: build preview clean

build:
	yarn build

preview:
	yarn preview

clean:
	rm -rf docs/.observable/dist
