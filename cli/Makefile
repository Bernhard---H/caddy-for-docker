.PHONY: clean dev test docker dist dist-upload

clean:
	find . -name '*.py[co]' -delete

# setup development environment
dev:
	python3 -m venv venv
	venv/bin/pip install -r requirements-dev.txt
	venv/bin/python setup.py develop
	@echo
	@echo "Setup of python3 virtual environment complete."
	@echo "  Now run: source venv/bin/activate"
	@echo

test:
	python -m pytest \
		-v \
		--cov=caddy_ctrl \
		--cov-report=term \
		--cov-report=html:coverage-report \
		tests/

docker: clean
	docker build -t caddy_ctrl:latest .

dist: clean
	rm -rf dist/*
	python setup.py sdist
	python setup.py bdist_wheel

dist-upload:
	twine upload dist/*
