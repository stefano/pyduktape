from tests import TestCase
from pyduktape import DuktapeContext


class TestContext(TestCase):
	def test_eval_simple_expression(self):
		ctx = DuktapeContext()

		res = ctx.eval_js('1 + 1')

		self.assertEqual(res, 2)
