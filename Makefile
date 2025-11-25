.PHONY: build preview etl data clean

build:
	yarn build

preview:
	yarn preview

etl: data  # No heavy ETL step, just alias to data
data:
	# No data generation needed for this notebook

clean:
	rm -rf docs/.observable/dist
