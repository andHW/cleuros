# valid
int MAIN()
{
	x := 4; # SAsn
	x; # Svar
	3; # SLit
	a := TRUE; # SBLit
	y := x + 1; # SAsn

	q := x > y;
	q := FALSE;

	if x > y {
		x := 1;
	}
	else {
		z := STUB();
		b := 1;
	}

	exchange x with y; # SSwap
	BLOCK(); # SCall w/o args

	myIntVar := 5 + x + PLAY(x, q); # SCall w/ args
	
	while x > 0 {
		x := 1;
		y := 9;
	}
}

int STUB()
{
	return 0;
}

int PLAY(a be int, b be bool)
{
	a := 1;
	b := TRUE;
	return a;
}

BLOCK()
{
	x := 3;
	{
		y := 2;
		z := 1;
	}
}
