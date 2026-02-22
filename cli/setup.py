
from setuptools import setup, find_packages
from caddy-ctrl.core.version import get_version

VERSION = get_version()

f = open('README.md', 'r')
LONG_DESCRIPTION = f.read()
f.close()

setup(
    name='caddy-ctrl',
    version=VERSION,
    description='CLI tool for easy management of the caddy server reverse proxy setup',
    long_description=LONG_DESCRIPTION,
    long_description_content_type='text/markdown',
    author='Bernhard Halbartschlager',
    author_email='halbart.bernhard+caddy-cli@gmail.com',
    url='https://github.com/Bernhard---H/caddy-for-docker',
    license='MIT',
    packages=find_packages(exclude=['ez_setup', 'tests*']),
    package_data={'caddy-ctrl': ['templates/*']},
    include_package_data=True,
    entry_points="""
        [console_scripts]
        caddy-ctrl = caddy-ctrl.main:main
    """,
)
