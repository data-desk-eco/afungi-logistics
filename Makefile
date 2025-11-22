.PHONY: build preview data clean

build:
	yarn build

preview:
	yarn preview

data:
	@echo "Building DuckDB database from flight tracks..."
	./scripts/build_database.sh
	@echo "Data updated"

clean:
	rm -rf docs/.observable/dist
