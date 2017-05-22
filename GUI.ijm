Dialog.create("User Settings");
Dialog.addString("Spot Size: ", "0-infinity", 12);
Dialog.addString("Circularity: ", "0-infinity", 12);
Dialog.addString("Bins: ", "0-50-100", 12);
Dialog.addNumber("% Offset Center: ", 50, 0, 6, "%");
Dialog.addNumber("% Offset Corners: ", 20, 0, 6, "%");
Dialog.addCheckbox("Convert", false);
Dialog.show();

size = Dialog.getString();
dash = indexOf(size, "-");
//TODO: Add some more checks.
if (dash == -1){
	exit("Invalid Spot Size.");
} else {
	size_up = substring(size, 0, dash);
	size_dn = substring(size, dash + 1);
}

circ = Dialog.getString();
dash = indexOf(circ, "-");
dasho = -1;
if (dash == -1){
	exit("Invalid Circularity.");
} else {
	circ_up = substring(circ, 0, dash);
	circ_dn = substring(circ, dash + 1);
}

binss = Dialog.getString();
bins = newArray(50);
dash = indexOf(binss, "-");
n = 0; 
if (dash == -1){
	exit("Invalid Bins.");
} else {
	while (dash != -1){
		bins[n++] = substring(binss, dasho + 1, dash);
		dasho = dash;
		dash = indexOf(binss, "-", dasho + 1);
	}
	bins[n] = substring(binss, dasho + 1);
}
bins = Array.trim(bins, n + 1);

centOff = Dialog.getNumber();
cornOff = Dialog.getNumber();

convert = Dialog.getCheckbox();

print("Upper Size Limit: " + size_up);
print("Lower Size Limit: " + size_dn);

print("Upper Circularity Limit: " + circ_up);
print("Lower Circularity Limit: " + circ_dn);

print("% Offset of Center: " + centOff);
print("% Offset of Corners: " + cornOff);

Array.print(bins);

print("Convert pixels to Units: " + convert);

