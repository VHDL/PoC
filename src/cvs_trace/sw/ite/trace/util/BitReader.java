package ite.trace.util;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;

import ite.trace.exceptions.InvalidLengthException;


/**
 * Reader zum Lesen von Binrdaten aus einer Eingangsdatei. Stell Methoden zum
 * Lesen von 32-Bit Strings zur Verfgung.
 * 
 * @author stefan alex
 * 
 */
public class BitReader {

	private FileInputStream fis;
	private int value;
	private int availableBits;

	/**
	 * Der Konstruktor.
	 * 
	 * @param dataFile
	 *            Die Datei, aus der gelesen wird.
	 * @throws FileNotFoundException
	 *             wenn die Datei nicht gefunden wurde.
	 */
	public BitReader(File dataFile) throws FileNotFoundException {
		this.fis = new FileInputStream(dataFile);
		availableBits = 0;
		value=0;
	}

	/**
	 * Gibt die gewnschte Anzahl an Bits als <code>String</code> zurck. Sind
	 * nicht mehr gengend Bits in der Datei vorhanden, so wird
	 * <code>null</code> zurckgegeben.
	 * 
	 * @param bits
	 *            die Anzahl der Bits
	 * @return die Bits
	 * @throws IllegalArgumentException
	 *             wenn die Lngenangabe kleiner als 1 ist.
	 * @throws IOException
	 *             wenn beim Lesen ein Fehler auftrat.
	 */
	public String getBitsAsString(int bits) throws IllegalArgumentException,
			IOException {
						
		if(bits<1)
			throw new IllegalArgumentException();
		
		String result = "";
		
		while(bits>availableBits){
			if(availableBits > 0){
				String tmpValue = to8BitBinaryString(value); 
				result = tmpValue.substring(0, availableBits)+result;
				bits-=availableBits;
			}
			value = fis.read();
			//System.out.println(to8BitBinaryString(value));
			if(value == -1)
				return null;
			availableBits = 8;
		}
		
		if(bits>=0){
			String tmpValue = to8BitBinaryString(value);
			result = tmpValue.substring(availableBits-bits, availableBits)+result;
			availableBits -= bits;			
		}
		
		return result;

	}
	
	/**
	 * Gibt die gewnschte Anzahl an Bits als <code>int</code> zurck. Sind
	 * nicht mehr gengend Bits in der Datei vorhanden, so wird
	 * <code>-1</code> zurckgegeben.
	 * 
	 * @param bits
	 *            die Anzahl der Bits
	 * @return die Bits
	 * @throws IllegalArgumentException
	 *             wenn die Lngenangabe kleiner als 1  oder größer als 31 ist.
	 * @throws IOException
	 *             wenn beim Lesen ein Fehler auftrat.
	 */
	public int getBitsAsInt(int bits) throws IllegalArgumentException,
			IOException {
		
		if(bits<1 | bits > 31)
			throw new IllegalArgumentException();
		
		int neededBits = bits;
		int result = 0;
		int resultShift = 0;
		
		while(neededBits>availableBits){
			if(availableBits > 0){
				result = result | ((value>>>(8-availableBits))<<resultShift);				
				neededBits-=availableBits;
				resultShift += availableBits;
			}
			value = fis.read();
			//System.out.println(to8BitBinaryString(value));
			if(value == -1)
				return -1;
			availableBits = 8;
		}
		
		if(neededBits>=0){
			result = result | (((value>>>(8-availableBits))<<resultShift)&(pot2(bits)-1));
			availableBits -= neededBits;			
		}
		
		return result;

	}
	
	/**
	 * Gibt die nächste Bit als <code>boolean</code> zurck. Sind
	 * nicht mehr gengend Bits in der Datei vorhanden, so wird
	 * <code>false</code> zurckgegeben.
	 * 
	 * @return die Bits
	 * @throws IOException
	 *             wenn beim Lesen ein Fehler auftrat.
	 */
	public boolean getBitAsBoolean() throws IOException {
		
		if(availableBits==0){
			value = fis.read();
			//System.out.println(to8BitBinaryString(value));
			if(value == -1)
				return false;
			availableBits = 8;
		}
		
		value = ((value >>> (8-availableBits))|1); 
		availableBits--;
		if(value > 0){
			return true;
		} else{
			return false;
		}
					
	}
	
	/**
	 * Gibt die gewnschte Anzahl an Bits als <code>BitVector</code> zurck. Sind
	 * nicht mehr gengend Bits in der Datei vorhanden, so wird
	 * <code>null</code> zurckgegeben.
	 * 
	 * @param bits
	 *            die Anzahl der Bits
	 * @return die Bits
	 * @throws IllegalArgumentException
	 *             wenn die Lngenangabe kleiner als 0 ist.
	 * @throws IOException
	 *             wenn beim Lesen ein Fehler auftrat.
	 */
	public BitVector getBitsAsBitVector(int bits) throws IllegalArgumentException,
			IOException {
		
		try {
					
			BitVector result = new BitVector(bits);			
			int resultIndex = 0;		
			while(bits>availableBits){
				if(availableBits > 0){
					result.setByteWithBitIndex(resultIndex, (byte)(value>>>(8-availableBits)));
					resultIndex += availableBits;
					bits-=availableBits;
				}
				value = fis.read();
				//System.out.println(to8BitBinaryString(value));
				if(value == -1)
					return null;
				availableBits = 8;
			}
			
			if(bits>=0){
				result.setByteWithBitIndex(resultIndex, (byte)(value>>>(8-availableBits)));			
				availableBits -= bits;			
			}
			
			return result;
			
		} catch(InvalidLengthException ile){
			throw new IllegalArgumentException();
		}
	}
	
	private String to8BitBinaryString(int value) {
		String st = Integer.toBinaryString(value);
		if (st.length() > 8) {
			return "";
		} else {
			for (int i = st.length(); i < 8; i++) {
				st = "0" + st;
			}
			return st;
		}
	}
	
	private int pot2(int exponent) {
		if ((exponent < 0) | (exponent > 31))
			return -1;

		int result = 1;
		for (int i = 0; i < exponent; i++) {
			result = result * 2;
		}
		return result;
	}

}
