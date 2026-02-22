
from pytest import raises
from caddy-ctrl.main import CaddyCliTest

def test_caddy-ctrl():
    # test caddy-ctrl without any subcommands or arguments
    with CaddyCliTest() as app:
        app.run()
        assert app.exit_code == 0


def test_caddy-ctrl_debug():
    # test that debug mode is functional
    argv = ['--debug']
    with CaddyCliTest(argv=argv) as app:
        app.run()
        assert app.debug is True


def test_command1():
    # test command1 without arguments
    argv = ['command1']
    with CaddyCliTest(argv=argv) as app:
        app.run()
        data,output = app.last_rendered
        assert data['foo'] == 'bar'
        assert output.find('Foo => bar')


    # test command1 with arguments
    argv = ['command1', '--foo', 'not-bar']
    with CaddyCliTest(argv=argv) as app:
        app.run()
        data,output = app.last_rendered
        assert data['foo'] == 'not-bar'
        assert output.find('Foo => not-bar')
