package ite.trace.util;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

import ite.trace.exceptions.InvalidBitRepresentationException;
import ite.trace.exceptions.InvalidLengthException;

/**
 * Ein <code>BitVector</code> ist eine beliebig (>=0) lange Folge von Bits. Er
 * wird als vorzeichenloser Wert interpretiert.
 * 
 * @author Alex, Stefan
 * 
 */
public class BitVector implements Serializable {

	private static final long serialVersionUID = 8883194452183506009L;

	private List<Boolean> value;

	/**
	 * Erstellt einen <code>BitVector</code> einer bestimmten Lnge grer/gleich
	 * 0. Der BitVector ist mit 0 initialisiert.
	 * 
	 * @param length
	 *            die Lnge des BitVectors
	 * @throws InvalidLengthException
	 *             wenn <code>length</code> kleiner 0 ist
	 */
	public BitVector(int length) throws InvalidLengthException {
		if (length < 0)
			throw new InvalidLengthException(length, 0);

		this.value = new ArrayList<Boolean>();
		for (int i = 0; i < length; i++)
			// Bits entsprechend der Lnge hinzufgen
			value.add(false);
	}

	/**
	 * Erstellt einen <code>BitVector</code> einer bestimmten Lnge grer/gleich
	 * 0. Alle Bits sind mit einem gegebenen Initialwert versehen.
	 * 
	 * @param length
	 *            die Lnge des BitVectors
	 * @param init
	 *            der Initialwert der Bits
	 * @throws InvalidLengthException
	 *             wenn <code>length</code> kleiner 0 ist
	 */
	public BitVector(int length, boolean init) throws InvalidLengthException {
		if (length < 0)
			throw new InvalidLengthException(length, 0);

		this.value = new ArrayList<Boolean>();
		for (int i = 0; i < length; i++)
			// Bits entsprechend der Lnge hinzufgen
			value.add(init);
	}

	/**
	 * Erstellt einen <code>BitVector</code> aus einem Integer-Wert und einer
	 * bestimmten Lnge. Ist die Lnge grer als der Integer-Wert Bits bentigt,
	 * wird mit 0 aufgefllt. Ist die Lnge geringer, oder kleiner 0, wird eine
	 * Ausnahme generiert. <code>intValue</code> darf keinen negativen Wert
	 * haben. Es wird entsprechend die Bit-Reprsentation gespeichert. Ist
	 * intValue 0, so darf der <code>BitVector</code> auch die Lnge 0 haben.
	 * 
	 * @param length
	 *            die Lnge (Anzahl der Stellen)
	 * @param intValue
	 *            der Wert
	 * @throws InvalidLengthException
	 *             wenn <code>length</code> nicht ausreicht, oder kleiner 0
	 *             ist.
	 * @throws InvalidBitRepresentationException
	 *             wenn <code>intValue</code> kleiner 0 ist.
	 * 
	 */
	public BitVector(int length, int intValue) throws InvalidLengthException,
			InvalidBitRepresentationException {
		value = new ArrayList<Boolean>();
		for (int i = 0; i < length; i++)
			// Bits entsprechend der Lnge hinzufgen
			value.add(false);

		setInt(intValue);
	}

	/**
	 * Erstellt einen <code>BitVector</code> aus einem Boolean-Wert. Die Lnge
	 * ist 1.
	 * 
	 * @param bit
	 *            der Wert des Bits
	 * 
	 */
	public BitVector(boolean bit) {
		value = new ArrayList<Boolean>();
		value.add(bit);
	}

	/**
	 * Erstellt einen <code>BitVector</code> aus einem Hexadezimal-Wert und
	 * einer bestimmten Lnge. Ist die Lnge grer, als der Hex-Wert Bits bentigt,
	 * wird mit 0 aufgefllt. Ist die Lnge geringer oder kleiner 0, wird eine
	 * Ausnahme generiert. Fhrende Nullen werden nicht entfernt und zhlen fr die
	 * Lnge mit. Lediglich die erste fhrende Null kann mit einem Bit gespeichert
	 * werden, die anderen mit jeweils vier Bits.
	 * 
	 * @param length
	 *            die Lnge (Anzahl der Stellen)
	 * @param hexString
	 *            der Wert
	 * @throws InvalidLengthException
	 *             wenn <code>length</code> nicht ausreicht, oder kleiner 0
	 *             ist.
	 * @throws InvalidBitRepresentationException
	 *             wenn <code>hexString</code> keinen hexadezimalen Wert
	 *             darstellt. Es darf kein <code>0x</code> oder <code>-</code>
	 *             vorangestellt sein.
	 */
	public BitVector(int length, String hexString)
			throws InvalidLengthException, InvalidBitRepresentationException {
		value = new ArrayList<Boolean>();
		for (int i = 0; i < length; i++)
			// Bits entsprechend der Lnge hinzufgen
			value.add(false);

		setHexString(hexString);
	}

	/**
	 * Erstellt einen <code>BitVector</code> der Lnge 0.
	 */
	public BitVector() {
		value = new ArrayList<Boolean>();
	}

	//
	// Getter-Methoden
	//

	/**
	 * Gibt eine binre Reprsentation als <code>String</code> zurck. Fhrende
	 * Nullen werden mit dargestellt.
	 * 
	 * @return eine binre Reprsentation als <code>String</code>
	 */
	public String getBinaryString() {
		String binStr = "";
		for (boolean digit : value) {
			binStr = getStringFromBool(digit) + binStr;
		}
		return binStr;
	}

	/**
	 * Gibt eine hexadezimale Reprsentation als <code>String</code> zurck.
	 * Fhrende Nullen werden mit dargestellt.
	 * 
	 * 
	 * @return eine hexadezimale Reprsentation als <code>String</code>
	 */

	public String getHexString() {
		String bin = ""; // Auslesen von 4 Bits, dann umwandeln
		String hex = "";

		for (int i = 0; i < value.size(); i++) {

			if (((i + 1) % 4 == 0) | (i == value.size() - 1)) { // 4 Bits
				// gelesen oder
				// letztes Bit

				bin = getStringFromBool(value.get(i)) + bin;
				hex = Integer.toHexString(Integer.parseInt(bin, 2)) + hex;
				bin = "";

			} else {

				bin = getStringFromBool(value.get(i)) + bin;
			}

		}

		return hex;

	}

	/**
	 * Gibt den Wert eines bestimmten Bits zurck. Hat dieser
	 * <code>BitVector</code> die Lnge 0, so kann diese Methode mit keinem
	 * gltigen Wert aufgerufen werden.
	 * 
	 * @param index
	 *            die gewnschte Stelle. Das niederwertiste Bit hat den Index 0.
	 * @return den Wert des Bits als <code>boolean</code>
	 * @throws IndexOutOfBoundsException
	 *             wenn der Index grer/gleich die Lnge oder kleiner 0.
	 */
	public boolean get(int index) throws IndexOutOfBoundsException {
		return value.get(index);
	}

	/**
	 * Gibt den Wert als <code>int</code> zurck. Dieser <code>BitVector</code>
	 * darf deshalb nicht lnger als 31 Bits sein. Negative Rckgabewerte werden
	 * nicht untersttzt. Bei einem leeren <code>BitVector</code> wird 0
	 * zurckgegeben.
	 * 
	 * @return den Wert als <code>int</code>
	 * @throws InvalidLengthException
	 *             wenn die Lnge des BitVectors grer als 31 ist
	 */
	public int getInt() throws InvalidLengthException {
		if (value.size() > 31)
			throw new InvalidLengthException(value.size(), 31);

		int result = 0;
		for (int i = 0; i < value.size(); i++)
			if (value.get(i) == true)
				result += pot2(i);

		return result;
	}

	/**
	 * Gibt den Wert <code>long</code> zurck. Dieser <code>BitVector</code>
	 * darf deshalb nicht lnger als 63 Bits sein. Negative Rckgabewerte werden
	 * nicht untersttzt. Bei einem leeren <code>BitVector</code> wird 0
	 * zurckgegeben.
	 * 
	 * @return den Wert als <code>long</code>
	 * @throws InvalidLengthException
	 *             wenn die Lnge des BitVectors grer als 63 ist
	 */
	public long getLong() throws InvalidLengthException {
		if (value.size() > 63)
			throw new InvalidLengthException(value.size(), 63);

		long result = 0;
		for (int i = 0; i < value.size(); i++)
			if (value.get(i) == true)
				result += pot2Long(i);

		return result;
	}

	/**
	 * 
	 * @return die Lnge
	 */
	public int getLength() {
		return value.size();
	}

	/**
	 * Gibt die hchstwertigsten i Bits als neuen <code>BitVector</code> zurck.
	 * Ist i = 0, so wird ein leerer <code>BitVector<code> zurckgegeben.
	 * 
	 * @param i
	 *            die Anzahl der Bits, die zurckgegeben werden sollen
	 * @return die hchstwertigsten i Bits
	 * @throws IndexOutOfBoundsException
	 *             wenn i kleiner 0 oder grer als die Lnge dieses
	 *             <code>BitVector</code>
	 */
	public BitVector getMSBits(int i) throws IndexOutOfBoundsException {
		return getSubvector(value.size() - i, value.size());
	}

	/**
	 * Gibt das hchstwertigste Bit zurck. Ist der Vector leer, so wird
	 * <code>false zurückgegeben.
	 * @return das hchstwertigste Bit
	 */
	public boolean getMSBit() {
		if (value.size() == 0)
			return false;

		return value.get(value.size() - 1);
	}

	/**
	 * Erhöht die Länge und füllt mit einen gegebenen Wert auf. Ist die Länge
	 * kleiner als die aktuelle Länge, so geschicht keine Änderung.
	 * 
	 * @param newLength
	 *            die neue Länge
	 * @param bit
	 *            der Wert
	 */
	public void fill(int newLength, boolean bit) {
		for (int i = value.size(); i < newLength; i++){
			value.add(bit);
		}
	}

	/**
	 * Erhöht die Länge um eins und hängt den gegebenen Wert an.
	 * 
	 * @param bit
	 *            der Wert
	 */
	public void append(boolean bit) {
		value.add(bit);
	}
	
	/**
	 * Gibt die niederwertigsten i Bits als neuen <code>BitVector</code>
	 * zurck. Ist i = 0, so wird ein leerer <code>BitVector</code>
	 * zurckgegeben.
	 * 
	 * @param i
	 *            die Anzahl der Bits, die zurckgegeben werden sollen
	 * @return die niederwertigsten i Bits
	 * @throws IndexOutOfBoundsException
	 *             wenn i kleiner 0 oder grer als die Lnge dieses BitVectors
	 */
	public BitVector getLSBits(int i) throws IndexOutOfBoundsException {
		return getSubvector(0, i);
	}

	/**
	 * Gibt einen TeilVector zurck. <code>startIndex</code> markiert das erste
	 * Bit, <code>stopIndex</code> das erste nicht-mehr enthaltende Bit. Es
	 * wird vom niederwertigen Bit (Index 0) zum hchstwertigen Bit gezhlt. Ist
	 * der <code>startIndex</code> gleich dem <code>stopIndex</code>, wird
	 * ein leerer <code>BitVector</code> zurckgegeben.
	 * 
	 * @param startIndex
	 *            der Index des ersten Bits des neuen Vectos
	 * @param stopIndex
	 *            der Index des ersten nicht mehr enthaltenden Bits
	 * @return einen neuen <code>BitVector</code>
	 * @throws IndexOutOfBoundsException
	 *             <code>(startIndex < 0 || stopIndex > size || startIndex >
	 *             stopIndex)</code>
	 */
	public BitVector getSubvector(int startIndex, int stopIndex)
			throws IndexOutOfBoundsException {

		if (startIndex > stopIndex)
			throw new IndexOutOfBoundsException(); // Rest wird durch Array
		// abgeprft

		List<Boolean> result = new ArrayList<Boolean>();

		for (int i = startIndex; i < stopIndex; i++)
			result.add(value.get(i).booleanValue());

		return new BitVector(result);
	}

	/**
	 * Gibt einen TeilVector zurck. <code>startIndex</code> markiert das erste
	 * Bit. Es wird vom niederwertigen Bit (Index 0) zum hchstwertigen Bit
	 * gezhlt.
	 * 
	 * @param startIndex
	 *            der Index des ersten Bits des neuen Vectos
	 * 
	 * @return einen neuen <code>BitVector</code>
	 * @throws IndexOutOfBoundsException
	 *             <code>(startIndex < 0 | startIndex > size)</code>
	 */
	public BitVector getSubvector(int startIndex)
			throws IndexOutOfBoundsException {

		// Bedingung Rest wird durch Array abgeprft

		List<Boolean> result = new ArrayList<Boolean>();

		for (int i = startIndex; i < value.size(); i++)
			result.add(value.get(i).booleanValue());

		return new BitVector(result);
	}

	//
	// Setter-Methoden
	// 

	/**
	 * Setzt eine neue Lnge Wird die Lnge erhht, wird mit 0 aufgefllt. Wird die
	 * Lnge reduziert, so werden die berschssigen Werte verworfen.
	 * 
	 * @param length
	 *            die neue Lnge
	 * @throws InvalidLengthException
	 *             wenn length kleiner 0 ist
	 */
	public void setLength(int length) throws InvalidLengthException {
		if (length < 0)
			throw new InvalidLengthException(length, 0);

		if (length > value.size()) { // Auffllen mit Nullen
			for (int i = length - value.size(); i > 0; i--) {
				value.add(false);
			}
		} else { // Bits entfernen
			for (int i = value.size() - length; i > 0; i--) {
				value.remove(value.size() - 1);
			}
		}
	}

	/**
	 * Setzt einen neuen Wert durch einen <code>String</code>, der eine
	 * hexadezimale Reprsentation enthlt. Ist die Lnge des
	 * <code>BitVector</code> nicht lang genug, wird eine Ausnahme generiert.
	 * Fhrende Nullen des Hex-Strings werden nicht entfernt. Lediglich die erste
	 * Ziffer kann als 0 mit einem Bit gespeichert werden. Ist der
	 * <code>String</code> leer, so wird 0 gesetzt.
	 * 
	 * @param hexString
	 *            der neue Wert als <code>String</code>
	 * @throws InvalidBitRepresentationException
	 *             wenn <code>hexString</code> keinen hexadezimalem Wert
	 *             entspricht. Es darf kein <code>0x</code> oder
	 *             <code>-</code> vorangestellt sein.
	 * @throws InvalidLengthException
	 *             wenn die Lnge dieses <code>BitVector</code> fr
	 *             <code>hexString</code> nicht ausreicht
	 */
	public void setHexString(String hexString)
			throws InvalidBitRepresentationException, InvalidLengthException {

		// berprfen der bentigten Lnge des Strings
		int reqLength;
		if (hexString.length() == 0) // leerer String
			reqLength = 0;
		else {
			reqLength = (hexString.length() - 1) * 4;
			char lastDigit = hexString.charAt(0); // letztes (erstes) Zeichen
			// braucht nicht unbedingt 4
			// Bits

			if (lastDigit == '0' | lastDigit == '1')
				reqLength = reqLength + 1;
			else if (lastDigit == '2' | lastDigit == '3')
				reqLength = reqLength + 2;
			else if (lastDigit == '4' | lastDigit == '5' | lastDigit == '6'
					| lastDigit == '7')
				reqLength = reqLength + 3;
			else
				reqLength = reqLength + 4;
		}

		if (reqLength > value.size())
			throw new InvalidLengthException(reqLength, value.size());

		// alle Werte zurcksetzen, da beim Parsen nicht alle gesetzt werden
		for (int i = 0; i < value.size(); i++)
			value.set(i, false);

		// parsen des Strings
		for (int i = 0; i < hexString.length(); i++) {

			switch (hexString.charAt(hexString.length() - 1 - i)) {
			case '0': {
				break;
			}
			case '1': {
				value.set(4 * i, true);
				break;
			}
			case '2': {
				value.set(4 * i, false);
				value.set(4 * i + 1, true);
				break;
			}
			case '3': {
				value.set(4 * i, true);
				value.set(4 * i + 1, true);
				break;
			}
			case '4': {
				value.set(4 * i, false);
				value.set(4 * i + 1, false);
				value.set(4 * i + 2, true);
				break;
			}
			case '5': {
				value.set(4 * i, true);
				value.set(4 * i + 1, false);
				value.set(4 * i + 2, true);
				break;
			}
			case '6': {
				value.set(4 * i, false);
				value.set(4 * i + 1, true);
				value.set(4 * i + 2, true);
				break;
			}
			case '7': {
				value.set(4 * i, true);
				value.set(4 * i + 1, true);
				value.set(4 * i + 2, true);
				break;
			}
			case '8': {
				value.set(4 * i, false);
				value.set(4 * i + 1, false);
				value.set(4 * i + 2, false);
				value.set(4 * i + 3, true);
				break;
			}
			case '9': {
				value.set(4 * i, true);
				value.set(4 * i + 1, false);
				value.set(4 * i + 2, false);
				value.set(4 * i + 3, true);
				break;
			}
			case 'a': {
				value.set(4 * i, false);
				value.set(4 * i + 1, true);
				value.set(4 * i + 2, false);
				value.set(4 * i + 3, true);
				break;
			}
			case 'b': {
				value.set(4 * i, true);
				value.set(4 * i + 1, true);
				value.set(4 * i + 2, false);
				value.set(4 * i + 3, true);
				break;
			}
			case 'c': {
				value.set(4 * i, false);
				value.set(4 * i + 1, false);
				value.set(4 * i + 2, true);
				value.set(4 * i + 3, true);
				break;
			}
			case 'd': {
				value.set(4 * i, true);
				value.set(4 * i + 1, false);
				value.set(4 * i + 2, true);
				value.set(4 * i + 3, true);
				break;
			}
			case 'e': {
				value.set(4 * i, false);
				value.set(4 * i + 1, true);
				value.set(4 * i + 2, true);
				value.set(4 * i + 3, true);
				break;
			}
			case 'f': {
				value.set(4 * i, true);
				value.set(4 * i + 1, true);
				value.set(4 * i + 2, true);
				value.set(4 * i + 3, true);
				break;
			}
			case 'A': {
				value.set(4 * i, false);
				value.set(4 * i + 1, true);
				value.set(4 * i + 2, false);
				value.set(4 * i + 3, true);
				break;
			}
			case 'B': {
				value.set(4 * i, true);
				value.set(4 * i + 1, true);
				value.set(4 * i + 2, false);
				value.set(4 * i + 3, true);
				break;
			}
			case 'C': {
				value.set(4 * i, false);
				value.set(4 * i + 1, false);
				value.set(4 * i + 2, true);
				value.set(4 * i + 3, true);
				break;
			}
			case 'D': {
				value.set(4 * i, true);
				value.set(4 * i + 1, false);
				value.set(4 * i + 2, true);
				value.set(4 * i + 3, true);
				break;
			}
			case 'E': {
				value.set(4 * i, false);
				value.set(4 * i + 1, true);
				value.set(4 * i + 2, true);
				value.set(4 * i + 3, true);
				break;
			}
			case 'F': {
				value.set(4 * i, true);
				value.set(4 * i + 1, true);
				value.set(4 * i + 2, true);
				value.set(4 * i + 3, true);
				break;
			}
			default: {
				throw new InvalidBitRepresentationException(hexString);
			}
			}

		}
	}

	/**
	 * Setzt den Wert durch einen <code>String</code>, der eine binre
	 * Reprsentation enthlt. Dieser muss gltig sein. Ist der String leer, wird
	 * der BitVector auf 0 gesetzt. Ist die gesetzte Lnge des BitVectors nicht
	 * ausreichend, wird eine Ausnahme generiert. Fhrende Nullen werden nicht
	 * entfernt.
	 * 
	 * @param binString
	 *            der <code>String</code>, der die Binrzahl enthlt
	 * @throws InvalidLengthException
	 *             wenn die Lnge fr den <code>binString</code> nicht ausreicht
	 * @throws InvalidBitRepresentationException
	 *             wenn <code>binString</code> keinen binrem Wert entspricht.
	 *             Es darf kein <code>0x</code> oder <code>-</code>
	 *             vorangestellt sein.
	 */
	public void setBinaryString(String binString)
			throws InvalidLengthException, InvalidBitRepresentationException {

		// berprfen der Lnge
		if (binString.length() > value.size())
			throw new InvalidLengthException(binString.length(), value.size());

		// Parsen des Strings
		for (int i = 0; i < binString.length(); i++) {

			switch (binString.charAt(binString.length() - 1 - i)) {
			case '0': {
				value.set(i, false);
				break;
			}
			case '1': {
				value.set(i, true);
				break;
			}
			default: {
				throw new InvalidBitRepresentationException(binString);
			}
			}
		}

		for (int i = binString.length(); i < value.size(); i++) { // auffllen
			// mit 0
			value.set(i, false);
		}
	}

	/**
	 * Setzt den Wert durch einen <code>int</code>-Wert. Ist die gesetzte
	 * Lnge nicht ausreichend, wird eine Ausnahme. Negative Eingabewerte werden
	 * nicht aktzeptiert. Der Wert 0 kann auch in einem leeren
	 * <code>BitVector</code> gespeichert werden.
	 * 
	 * @param intValue
	 *            der Wert
	 * @throws InvalidLengthException
	 *             wenn die Lnge nicht ausreicht
	 * @throws InvalidBitRepresentationException
	 *             wenn der Integer-Wert kleiner 0 ist.
	 */
	public void setInt(int intValue) throws InvalidLengthException,
			InvalidBitRepresentationException {

		if (intValue < 0)
			throw new InvalidBitRepresentationException(Integer
					.toString(intValue));

		// Berechnen der bentigten Lnge
		int reqLength = 0;
		for (int i = 0; i < 32; i++) {
			if (pot2(i) - 1 >= intValue) {
				reqLength = i;
				break;
			}
		}

		if (reqLength > value.size())
			throw new InvalidLengthException(reqLength, value.size());

		for (int i = reqLength - 1; i >= 0; i--) {
			int part = pot2(i);
			if (part <= intValue) {
				value.set(i, true);
				intValue -= part;
			} else {
				value.set(i, false);
			}
		}

		for (int i = reqLength; i < value.size(); i++) { // auffllen mit 0
			value.set(i, false);
		}

	}

	/**
	 * Setzt den Wert eines bestimmten Bits neu.
	 * 
	 * @param index
	 *            der Index dieses Bits. 0 markiert das niederwertigste Bit.
	 * @param bit
	 *            ein Bit als boolean
	 * @throws IndexOutOfBoundsException
	 *             wenn der Index grer/gleich die Lnge oder kleiner 0.
	 */
	public void set(int index, boolean bit) throws IndexOutOfBoundsException {
		value.set(index, bit);
	}

	/**
	 * Setzt alle Werte ab des Indexes auf den boolean-Wert.
	 * 
	 * @param index
	 *            der Index dieses Bits. 0 markiert das niederwertigste Bit.
	 * @param bit
	 *            ein Bit als boolean
	 * @throws IndexOutOfBoundsException
	 *             wenn der Index grer/gleich die Lnge oder kleiner 0.
	 */
	public void setBits(int index, boolean bit)
			throws IndexOutOfBoundsException {
		if (index < 0 | index >= value.size())
			throw new IndexOutOfBoundsException();

		for (int i = index; i < value.size(); i++)
			value.set(i, bit);
	}

	/**
	 * Setzt an die Postition eines Bytes einen bestimmten Wert. Füllt die Länge
	 * des Vectors am Ende kein volles Byte, so wird das Byte in Teilen
	 * übernommen.
	 * 
	 * 
	 * @param byteIndex
	 *            die Position des Bytes
	 * @param b
	 *            das zu setzende Byte
	 * @throws IndexOutOfBoundsException
	 *             Wenn ein Byte gesetzt werden soll, das nicht innerhalb der
	 *             Länge ist.
	 */
	public void setByte(int byteIndex, byte b) throws IndexOutOfBoundsException {
		int extBytes = (int) Math.ceil((double) value.size() / 8.0);

		if (byteIndex + 1 > extBytes | byteIndex < 0)
			throw new IndexOutOfBoundsException();

		for (int i = 0; i < 8; i++) {
			if (byteIndex * 8 + i < value.size()) {
				value.set(byteIndex * 8 + i, (b & (int) Math.pow(2, i)) > 0);
			}
		}
	}

	/**
	 * Setzt ein Byte an eine bestimmte Postition. Füllt die Länge des Vectors
	 * am Ende kein volles Byte, so wird das Byte in Teilen übernommen.
	 * 
	 * 
	 * @param byteIndex
	 *            die Position des Bytes
	 * @param b
	 *            das zu setzende Byte
	 * @throws IndexOutOfBoundsException
	 *             Wenn ein Byte gesetzt werden soll, das nicht innerhalb der
	 *             Länge ist.
	 */
	public void setByteWithBitIndex(int bitIndex, byte b)
			throws IndexOutOfBoundsException {
		if (bitIndex < 0 | bitIndex > value.size() + 6)
			throw new IndexOutOfBoundsException();

		for (int i = 0; i < 8; i++) {
			if (bitIndex + i < value.size()) {
				value.set(bitIndex + i, (b & (pot2(i))) > 0);
			}
		}
	}

	/**
	 * Gibt ein Byte des Vectors zurück. Stehen am Ende des Vectors nicht
	 * genügend Bits zur Verfügung, so wird mit 0 aufgefüllt.
	 * 
	 * @param byteIndex
	 *            der Index des Bytes
	 * @return ein Byte
	 * @throws IndexOutOfBoundsException
	 *             der Index liegt nicht innerhalb des Vector.
	 */
	public byte getByte(int byteIndex) throws IndexOutOfBoundsException {
		int extBytes = (int) Math.ceil((double) value.size() / 8.0);

		if (byteIndex + 1 > extBytes | byteIndex < 0)
			throw new IndexOutOfBoundsException();

		byte b = 0;

		for (int i = 0; i < 8; i++) {
			if (byteIndex * 8 + i < value.size())
				if (value.get(byteIndex * 8 + i))
					b = (byte) (b | (1 << i));

		}
		return b;
	}

	//
	// Operatoren
	//

	/**
	 * Fhrt eine AND-Verknpfung des <code>BitVector</code>s mit einem Zweiten
	 * durch und gibt das Ergebnis als neuen <code>BitVector</code> zurck. Das
	 * Ergebnis hat die Lnge der Lngsten der beiden Operanden.
	 * 
	 * @param bitVector
	 *            der zweite Operand
	 * @return einen neuen <code>BitVector</code>
	 */
	public BitVector and(BitVector bitVector) {

		List<Boolean> result = new ArrayList<Boolean>();
		List<Boolean> operand = bitVector.getList();

		for (int i = 0; i < min(value.size(), operand.size()); i++) {
			result.add(value.get(i) & operand.get(i));
		}

		if (value.size() > operand.size()) {
			for (int i = operand.size(); i < value.size(); i++) {
				result.add(false);
			}
		} else {
			for (int i = value.size(); i < operand.size(); i++) {
				result.add(false);

			}
		}

		return new BitVector(result);

	}

	/**
	 * Fhrt eine OR-Verknpfung des <code>BitVector</code>s mit einem Zweiten
	 * durch und gibt das Ergebnis als neuen <code>BitVector</code> zurck. Das
	 * Ergebnis hat die Lnge der Lngsten der beiden Operanden.
	 * 
	 * @param bitVector
	 *            ein Operand
	 * @return einen neuen <code>BitVector</code>
	 */
	public BitVector or(BitVector bitVector) {

		List<Boolean> result = new ArrayList<Boolean>();
		List<Boolean> operand = bitVector.getList();

		for (int i = 0; i < min(value.size(), operand.size()); i++) {
			result.add(value.get(i) | operand.get(i));
		}

		if (value.size() > operand.size()) {
			for (int i = operand.size(); i < value.size(); i++) {
				result.add(value.get(i).booleanValue());
			}
		} else {
			for (int i = value.size(); i < operand.size(); i++) {
				result.add(operand.get(i).booleanValue());
			}
		}

		return new BitVector(result);

	}

	/**
	 * Gibt einen neuen <code>BitVector</code> zurck, der den invertierten
	 * Wert enthlt.
	 * 
	 * @return einen neuen <code>BitVector</code>
	 */
	public BitVector not() {
		List<Boolean> result = new ArrayList<Boolean>();

		for (int i = 0; i < value.size(); i++) {
			result.add(!value.get(i));
		}
		return new BitVector(result);
	}

	/**
	 * Fhrt eine XOR-Verknpfung des <code>BitVector</code>s mit einem Zweiten
	 * durch und gibt das Ergebnis als neuen <code>BitVector</code> zurck. Das
	 * Ergebnis hat die Lnge der Lngsten der beiden Operanden.
	 * 
	 * @param bitVector
	 *            ein Operand
	 * @return einen neuen <code>BitVector</code>
	 */
	public BitVector xor(BitVector bitVector) {
		List<Boolean> result = new ArrayList<Boolean>();
		List<Boolean> operand = bitVector.getList();

		for (int i = 0; i < min(value.size(), operand.size()); i++) {
			result.add(value.get(i) ^ operand.get(i));
		}
		if (value.size() > operand.size()) {
			for (int i = operand.size(); i < value.size(); i++) {
				result.add(value.get(i).booleanValue());
			}
		} else {
			for (int i = value.size(); i < operand.size(); i++) {
				result.add(operand.get(i).booleanValue());
			}
		}

		return new BitVector(result);
	}

	/**
	 * Fhrt eine NAND-Verknpfung des <code>BitVector</code>s mit einem
	 * zweiten durch und gibt das Ergebnis als neuen <code>BitVector</code>
	 * zurck. Das Ergebnis hat die Lnge der Lngsten der beiden Operanden.
	 * 
	 * @param bitVector
	 *            der Operand
	 * @return einen neuen <code>BitVector</code>
	 */
	public BitVector nand(BitVector bitVector) {
		List<Boolean> result = new ArrayList<Boolean>();
		List<Boolean> operand = bitVector.getList();

		for (int i = 0; i < min(value.size(), operand.size()); i++) {
			result.add(!(value.get(i) & operand.get(i)));
		}
		if (value.size() > operand.size()) {
			for (int i = operand.size(); i < value.size(); i++) {
				result.add(true);
			}
		} else {
			for (int i = value.size(); i < operand.size(); i++) {
				result.add(true);
			}
		}

		return new BitVector(result);
	}

	/**
	 * Fhrt eine NOR-Verknpfung des <code>BitVector</code>s mit einem Zweiten
	 * durch und gibt das Ergebnis als neuen <code>BitVector</code> zurck. Das
	 * Ergebnis hat die Lnge der Lngsten der beiden Operanden.
	 * 
	 * @param bitVector
	 *            der Operand
	 * @return einen neuen <code>BitVector</code>
	 */
	public BitVector nor(BitVector bitVector) {
		List<Boolean> result = new ArrayList<Boolean>();
		List<Boolean> operand = bitVector.getList();

		for (int i = 0; i < min(value.size(), operand.size()); i++) {
			result.add(!(value.get(i) | operand.get(i)));
		}
		if (value.size() > operand.size()) {
			for (int i = operand.size(); i < value.size(); i++) {
				result.add(!value.get(i));
			}
		} else {
			for (int i = value.size(); i < operand.size(); i++) {
				result.add(!operand.get(i));
			}
		}

		return new BitVector(result);
	}

	/**
	 * Addiert diesen <code>BitVector</code>s mit einem Zweiten und gibt das
	 * Ergebnis als neuen <code>BitVector</code> zurck. Beide Vektoren sollten
	 * die gleiche Länge haben. Das Ergebnis beachtet nicht den letzten Carry.
	 * 
	 * @param bitVector
	 *            der Operand
	 * @return einen neuen <code>BitVector</code>
	 * @throws IllegalArgumentException
	 *             wenn die beiden Vektoren nicht die gleiche Länge haben.
	 */
	public BitVector addIngoreLastCarry(BitVector bitVector)
			throws IllegalArgumentException {
		List<Boolean> result = new ArrayList<Boolean>();
		List<Boolean> operand = bitVector.getList();
		boolean carry = false;
		if (value.size() != operand.size())
			throw new IllegalArgumentException();

		for (int i = 0; i < value.size(); i++) {
			if (value.get(i) & operand.get(i)) {
				if (carry) {
					result.add(true);
				} else {
					result.add(false);
				}
				carry = true;
			} else {
				if (value.get(i) ^ operand.get(i)) {
					if (carry) {
						result.add(false);
						carry = true;
					} else {
						carry = false;
						result.add(true);
					}
				} else {
					result.add(carry);
					carry = false;
				}
			}
		}

		return new BitVector(result);
	}

	/**
	 * Verbindet diesen und den Parameter zu einem neuen BitVector. Die Lngen
	 * addieren sich. Der Parameter wird hherwertig abgespeichert.
	 * 
	 * @param bitVector
	 *            der hherwertige Teil des Ergebnisses
	 * @return einen neuen <code>BitVector</code>
	 */
	public BitVector concat(BitVector bitVector) {

		List<Boolean> result = new ArrayList<Boolean>();
		List<Boolean> operand = bitVector.getList();

		for (boolean b : value)
			result.add(b);

		for (boolean b : operand)
			result.add(b);

		return new BitVector(result);
	}

	/**
	 * Gibt den inkrementierten Wert dieses BitVectors als neues Objekt zurck.
	 * Die Lnge bleibt unverndert, es gibt u.U. einen berlauf. Ist der
	 * <code>BitVector</code> leer, ist das Ergebnis auch ein leerer
	 * <code>BitVector</code>.
	 * 
	 * @return einen neuen BitVector
	 */
	public BitVector increment() {
		List<Boolean> result = new ArrayList<Boolean>();

		for (int i = 0; i < value.size(); i++) {

			if (value.get(i) == true) {
				result.add(false);
			} else {
				result.add(true);
				break;
			}
		}

		// Auffllen
		for (int i = result.size(); i < value.size(); i++) {
			result.add(value.get(i).booleanValue());
		}

		return new BitVector(result);
	}

	/**
	 * Initialisiert ein neues <code>BitVector</code>-Objekt mit den selben
	 * Werten wie diesen. Ist der <code>BitVector</code> leer, ist das
	 * Ergebnis auch ein leerer <code>BitVector</code>.
	 * 
	 * @return einen neuen <code>BitVector</code>
	 */
	public BitVector copy() {
		List<Boolean> result = new ArrayList<Boolean>();

		for (int i = 0; i < value.size(); i++) {
			result.add(value.get(i).booleanValue());
		}
		return new BitVector(result);

	}

	/**
	 * Gibt den dekrementierten Wert dieses <code>BitVector</code>s als neues
	 * Objekt zurck. Die Lnge bleibt unverndert, es gibt u.U. einen berlauf. Ist
	 * der <code>BitVector</code> leer, ist das Ergebnis auch ein leerer
	 * BitVector.
	 * 
	 * @return einen neuen BitVector
	 */
	public BitVector decrement() {//

		List<Boolean> result = new ArrayList<Boolean>();

		for (int i = 0; i < value.size(); i++) {

			if (value.get(i) == true) {
				result.add(false);
				break;
			} else {
				result.add(true);
			}
		}

		// Auffllen
		for (int i = result.size(); i < value.size(); i++) {
			result.add(value.get(i).booleanValue());
		}

		return new BitVector(result);
	}

	/**
	 * Vergleicht diesen mit einem weiteren <code>BitVector</code>. Die Lngen
	 * mssen ebenfalls bereinstimmen.
	 * 
	 * @param bitVector
	 *            der Vergleichswert
	 * @return <code>true</code>, wenn beide <code>BitVector</code>en
	 *         bereinstimmen, sonst <code>false</code>.
	 */
	public boolean equals(BitVector bitVector) {
		List<Boolean> bvList = bitVector.getList();

		if (value.size() != bvList.size())
			return false;

		for (int i = 0; i < value.size(); i++) {
			if (value.get(i) != bvList.get(i))
				return false;
		}

		return true;
	}

	/**
	 * berschreibt die <code>equals</code>-Methode der <code>Object</code>
	 * -Superklasse.
	 */
	public boolean equals(Object obj) {
		if (obj.getClass().getName().equals("util.BitVector"))
			return equals((BitVector) obj);
		else
			return false;

	}

	/**
	 * Extrahiert bestimmte Bits aus diesem <code>BitVector</code> und fhrt
	 * sie in einem neuen wieder zusammen. Die bentigten Bits werden mit einem
	 * Array aus <code>boolean</code>-Werte gekennzeichnet. Ist der Wert an
	 * der Stelle i <code>true</code>, so wird das i-te Bit dieses Vektors in
	 * den neuen <code>BitVector</code> bernommen. Die Lnge des
	 * <code>boolean</code>-Array muss mit der Lnge dieses
	 * <code>BitVector</code>s bereinstimmen. Ist kein Bit mit true
	 * marktiert, wird ein BitVector der Lnge 0 zurckgegeben.
	 * 
	 * @param bits
	 *            die markierten Bits
	 * @return einen neuen <code>BitVector</code>
	 * @throws InvalidLengthException
	 *             wenn die Lnge von bits nicht der Lnge des Vectors entspricht
	 */
	public BitVector extract(boolean[] bits) throws InvalidLengthException {
		if (bits.length != value.size())
			throw new InvalidLengthException(bits.length, value.size());

		List<Boolean> result = new ArrayList<Boolean>();

		for (int i = 0; i < bits.length; i++) {
			if (bits[i] == true) {
				result.add(value.get(i).booleanValue());
			}
		}

		return new BitVector(result);
	}

	/**
	 * Verteilt die Bits aus diesem <code>BitVector</code> und fhrt sie in
	 * einem neuen wieder zusammen. Die Position der Bits werden mit einem Array
	 * aus <code>boolean</code>-Werte gekennzeichnet. Die Anzahl der
	 * <code>true</code>-Eintge <code>boolean</code>-Array muss mit der
	 * Lnge dieses <code>BitVector</code>s bereinstimmen. Die Lnge des
	 * Ergebnisses ist die Lnge des Arrays.
	 * 
	 * @param bits
	 *            die markierten Bits
	 * @return einen neuen <code>BitVector</code>
	 * @throws InvalidLengthException
	 *             wenn die Anzahl der markierten Bits nicht der Lnge des
	 *             Vectors entspricht
	 */
	public BitVector distribute(boolean[] bits) throws InvalidLengthException {
		int cnt = 0;
		for (int i = 0; i < bits.length; i++) {
			if (bits[i])
				cnt++;
		}
		if (cnt != value.size())
			throw new InvalidLengthException(cnt, value.size());

		BitVector result = new BitVector(bits.length);
		int index = 0;
		for (int i = 0; i < bits.length; i++) {
			if (bits[i]) {
				result.set(i, get(index));
				index++;
			}
		}
		return result;
	}

	/**
	 * Gibt <code>true</code> zurck, wenn dieser Vector leer ist.
	 */
	public boolean isSimple() {
		if (value.size() == 0)
			return true;
		else
			return false;
	}

	/**
	 * Gibt <code>true</code> zurck, wenn dieser Vector 0 ist ist.
	 */
	public boolean isZero() {
		boolean isZero = true;
		for (int i = 0; i < value.size(); i++) {
			if (value.get(i)) {
				isZero = false;
				break;
			}
		}
		return isZero;
	}

	/**
	 * Fgt an den diesen <code>BitVector</code> i-mal sich selbst an und gibt
	 * ein neues Objekt zurck Die Lnge ist (i+1)*Length. Bei i<0 wird null
	 * zurckgegeben, bei i=0 eine Kopie dieses <code>BitVectors</code>.
	 */
	public BitVector recur(int i) {
		if (i < 0)
			return null;

		List<Boolean> result = new ArrayList<Boolean>();
		for (int cnt = 0; cnt <= i; cnt++) {
			for (int j = 0; j < value.size(); j++) {
				result.add(value.get(j).booleanValue());
			}
		}
		return new BitVector(result);
	}

	/**
	 * Gibt den Abstand zwischen diesem <code>BitVector</code> und dem
	 * Argument an. Beide Werte mssen krzer als 32 Bit sein.
	 * 
	 * @param vector
	 *            der Vergleichswert
	 * @return der Abstand
	 * @throws InvalidLengthException
	 *             ein <code>BitVector</code> ist lnger als 31 Bits.
	 */
	public int getDistance(BitVector vector) throws InvalidLengthException {
		int value1 = getInt();
		int value2 = vector.getInt();

		if (value2 > value1)
			return value2 - value1;
		else
			return value1 - value2;

	}

	public String toString() {
		return getBinaryString();
	}

	//
	// private Methoden
	//

	/**
	 * Berechnen einer Zweier-Potenz. Der Exponent muss grer/gleich 0 sein und
	 * kleiner 32 sein. Sonst wird -1 zurckgegeben.
	 * 
	 * @param exponent
	 *            der Exponent
	 * @return 2 hoch dem Exponenten
	 */
	private int pot2(int exponent) {
		if ((exponent < 0) | (exponent > 31))
			return -1;

		int result = 1;
		for (int i = 0; i < exponent; i++) {
			result = result * 2;
		}
		return result;
	}

	/**
	 * Berechnen einer Zweier-Potenz. Der Exponent muss grer/gleich 0 sein und
	 * kleiner 63 sein. Sonst wird -1 zurckgegeben.
	 * 
	 * @param exponent
	 *            der Exponent
	 * @return 2 hoch dem Exponenten
	 */
	private long pot2Long(int exponent) {
		if ((exponent < 0) | (exponent > 63))
			return -1;

		long result = 1;
		for (int i = 0; i < exponent; i++) {
			result = result * 2;
		}
		return result;
	}

	/**
	 * Privater Konstruktor. Erstellt einen neuen BitVector aus einer Liste von
	 * Bits.
	 * 
	 * @param value
	 */
	private BitVector(List<Boolean> value) {
		this.value = value;
	}

	/**
	 * Gibt den Kleineren der beiden Parameter zurck.
	 * 
	 * @param a
	 *            Parameter 1
	 * @param b
	 *            Parameter 2
	 * @return der kleinere der beiden Paramter
	 */
	private int min(int a, int b) {
		if (a > b)
			return b;
		else
			return a;
	}

	/**
	 * Gibt eine Referenz auf die <code>Boolean</code>-Liste zurck, die den
	 * gespeicherten Wert enthlt.
	 * 
	 */
	private List<Boolean> getList() {
		return value;
	}

	/**
	 * Wandelt einen <code>boolean</code>-Wert in einen <code>String</code>
	 * in positiver Logik um.
	 * 
	 * @param value
	 *            der <code>boolean</code>-Wert
	 * @return "0" (fr <code>false</code>) oder "1" (fr <code>true</code>)
	 */
	private String getStringFromBool(boolean value) {
		if (value)
			return "1";
		else
			return "0";

	}

}