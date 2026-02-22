
from setuptools import setup, find_packages
from caddy_ctrl.core.version import get_version

VERSION = get_version()

f = open('README.md', 'r')
LONG_DESCRIPTION = f.read()
f.close()

setup(
    name='caddy_ctrl',
    version=VERSION,
    description='CLI tool for easy management of the caddy server reverse proxy setup',
    long_description=LONG_DESCRIPTION,
    long_description_content_type='text/markdown',
    author='Bernhard Halbartschlager',
    author_email='halbart.bernhard+caddy-cli@gmail.com',
    url='https://github.com/Bernhard---H/caddy-for-docker',
    license='MIT',
    packages=find_packages(exclude=['ez_setup', 'tests*']),
    package_data={'caddy_ctrl': ['templates/*']},
    include_package_data=True,
    entry_points="""
        [console_scripts]
        caddy_ctrl = caddy_ctrl.main:main
    """,
)
