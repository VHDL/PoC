package ite.trace.processing.traceConfig.decompress;

import java.util.ArrayList;
import java.util.List;

import ite.trace.processing.traceConfig.tracer.InstTracer;
import ite.trace.processing.traceConfig.tracer.MemTracer;
import ite.trace.processing.traceConfig.tracer.MessageTracer;
import ite.trace.processing.traceConfig.tracerInstance.InstTracerInstance;
import ite.trace.processing.traceConfig.tracerInstance.MemTracerInstance;
import ite.trace.processing.traceConfig.tracerInstance.MessageTracerInstance;
import ite.trace.processing.traceConfig.tracerInstance.TracerInstance;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidLengthException;

/**
 * Checks a trace, coming from an trace_testbed-environment.
 * @author Stefan Alex
 *
 */
public class Checker {

	private BitVector testVector1;
	private TracerChecker[][] tracerChecker;
	
	public Checker(List<TracerInstance> tracerList){
			
		try{
			this.testVector1 = new BitVector(64);	
		} catch (InvalidLengthException ile){
			ile.printStackTrace();
		}
		
		tracerChecker = new TracerChecker[tracerList.size()][]; 
		
		for (int k = 0; k<tracerList.size(); k++){
			TracerInstance t = tracerList.get(k);
			
			int i = t.getInputNo();
			
			if(t instanceof InstTracerInstance){
								
				InstTracer instTracer = (InstTracer) t.getDefinition();
				int valueOffset = 0;
				List<Integer[]> valueBits = new ArrayList<Integer[]>();
				List<Integer[]> valueInvBits = new ArrayList<Integer[]>();	
				
				if(instTracer.getAdrPort().getId() == 1){
					// shap bytecode
					valueOffset = 8;
					Integer[] valueBits_i_0 = new Integer[12];
					Integer[] valueInvBits_i_0 = new Integer[1];
					valueBits_i_0[0] = 0;
					valueBits_i_0[1] = 1;
					valueBits_i_0[2] = 2;
					valueBits_i_0[3] = 3;
					valueBits_i_0[4] = 4;
					valueBits_i_0[5] = 5;
					valueBits_i_0[6] = 6;
					valueBits_i_0[7] = 7;
					valueBits_i_0[8] = 8;
					valueBits_i_0[9] = 9;
					valueBits_i_0[10] = 11;
					valueBits_i_0[11] = 12;
					valueInvBits_i_0[0] = 10;
					
					Integer[] valueBits_i_1 = new Integer[12];
					Integer[] valueInvBits_i_1 = new Integer[1];
					valueBits_i_1[0] = 0;
					valueBits_i_1[1] = 1;
					valueBits_i_1[2] = 2;
					valueBits_i_1[3] = 3;
					valueBits_i_1[4] = 4;
					valueBits_i_1[5] = 5;
					valueBits_i_1[6] = 6;
					valueBits_i_1[7] = 7;
					valueBits_i_1[8] = 8;
					valueBits_i_1[9] = 9;
					valueBits_i_1[10] = 10;
					valueBits_i_1[11] = 12;
					valueInvBits_i_1[0] = 11;
					
					valueBits.add(valueBits_i_0);
					valueInvBits.add(valueInvBits_i_0);
					valueBits.add(valueBits_i_1);
					valueInvBits.add(valueInvBits_i_1);
				}
				
				if(instTracer.getAdrPort().getId() == 5){
					// shap microcode
					valueOffset = 0;
					Integer[] valueBits_i = new Integer[2];
					Integer[] valueInvBits_i = new Integer[0];
					valueBits_i[0] = 0;
					valueBits_i[1] = 1+i;
					valueBits.add(valueBits_i);
					valueInvBits.add(valueInvBits_i);
				}
				tracerChecker[k] = new TracerChecker[1];
				tracerChecker[k][0] = new TracerChecker(valueBits, valueInvBits, instTracer.getAdrPort().getWidth(), valueOffset);
				
			}

			if(t instanceof MemTracerInstance){
				
				MemTracer memTracer = (MemTracer) t.getDefinition();
				int adr1Offset = 0;
				int adr2Offset = 0;
				int dataOffset = 0;
				int rwOffset = 0;
				int sourceOffset = 0;
				List<Integer[]> adr1Bits = new ArrayList<Integer[]>();
				List<Integer[]> adr1InvBits = new ArrayList<Integer[]>();
				List<Integer[]> adr2Bits = new ArrayList<Integer[]>();
				List<Integer[]> adr2InvBits = new ArrayList<Integer[]>();
				List<Integer[]> dataBits = new ArrayList<Integer[]>();
				List<Integer[]> dataInvBits = new ArrayList<Integer[]>();
				List<Integer[]> sourceBits = new ArrayList<Integer[]>();
				List<Integer[]> sourceInvBits = new ArrayList<Integer[]>();
				List<Integer[]> rwBits = new ArrayList<Integer[]>();
				List<Integer[]> rwInvBits = new ArrayList<Integer[]>();
				boolean adr2 = false;
				boolean src = false;
				
				if(memTracer.getAdrPortCnt() == 2)
					if (memTracer.getAdrPorts().get(0).getId() == 8 & memTracer.getAdrPorts().get(1).getId() == 9 & memTracer.getDataPort().getId() == 10 & memTracer.getSourcePort() == null & memTracer.getRwPort().getId() == 12){
						// shap memman
						adr2 = true;
						src = false;
						
						adr1Offset=16;						
						Integer[] adr1Bits_i = new Integer[7];
						Integer[] adr1InvBits_i = new Integer[2];
						for(int j = 0; j<6; j++)
							adr1Bits_i[j] = j;
						adr1Bits_i[6] = 6;
						adr1InvBits_i[0] = 7;
						adr1InvBits_i[1] = 8;
						adr1Bits.add(adr1Bits_i);
						adr1InvBits.add(adr1InvBits_i);
						
						adr2Offset=8;						
						Integer[] adr2Bits_i = new Integer[7];
						Integer[] adr2InvBits_i = new Integer[1];
						for(int j = 0; j<6; j++)
							adr2Bits_i[j] = j;
						adr2Bits_i[6] = 7;
						adr2InvBits_i[0] = 6;
						adr2Bits.add(adr2Bits_i);
						adr2InvBits.add(adr2InvBits_i);
						
						dataOffset=1;				
						Integer[] dataBits_i = new Integer[7];
						Integer[] dataInvBits_i = new Integer[1];
						for(int j = 0; j<6; j++)
							dataBits_i[j] = j;
						dataBits_i[6] = 8;
						dataInvBits_i[0] = 6;
						dataBits.add(dataBits_i);
						dataInvBits.add(dataInvBits_i);
								
						rwOffset = 0;
						rwBits = adr2Bits;
						rwInvBits = adr2InvBits;
				}
				
				if(memTracer.getAdrPortCnt() == 1)
					if (memTracer.getAdrPorts().get(0).getId() == 13 & memTracer.getDataPort().getId() == 14 & memTracer.getSourcePort().getId() == 15 & memTracer.getRwPort().getId() == 16){
						// shap wishbone
						src = true;
						adr1Offset = 0;						
						Integer[] adr1Bits_i = new Integer[7];
						Integer[] adr1InvBits_i = new Integer[0];
						adr1Bits_i[0] = 0;
						adr1Bits_i[1] = 1;
						adr1Bits_i[2] = 2;
						adr1Bits_i[3] = 3;
						adr1Bits_i[4] = 4;
						adr1Bits_i[5] = 5;
						adr1Bits_i[6] = 6;
						adr1Bits.add(adr1Bits_i);
						adr1InvBits.add(adr1InvBits_i);
						
						dataOffset = 0;						
						Integer[] dataBits_i = new Integer[7];
						Integer[] dataInvBits_i = new Integer[0];
						dataBits_i[0] = 0;
						dataBits_i[1] = 1;
						dataBits_i[2] = 2;
						dataBits_i[3] = 3;	
						dataBits_i[4] = 4;	
						dataBits_i[5] = 5;
						dataBits_i[6] = 7;
						dataBits.add(dataBits_i);
						dataInvBits.add(dataInvBits_i);
						
						sourceOffset = 8;						
						sourceBits.add(adr1Bits_i);
						sourceBits.add(dataBits_i);
						sourceInvBits.add(adr1InvBits_i);						
						sourceInvBits.add(dataInvBits_i);
						rwOffset = 9;
						rwBits = adr1Bits;	
						rwInvBits = adr1InvBits;
				}
				
				if (adr2 & src)
					tracerChecker[k] = new TracerChecker[5];
				if ((!adr2 & src) | (adr2 & !src))
					tracerChecker[k] = new TracerChecker[4];
				if (!adr2 & !src)
					tracerChecker[k] = new TracerChecker[3];
				
				tracerChecker[k][0] = new TracerChecker(adr1Bits, adr1InvBits, memTracer.getAdrPorts().get(0).getWidth(), adr1Offset);
				int off = 0;
				if (adr2){
					tracerChecker[k][1] = new TracerChecker(adr2Bits, adr2InvBits, memTracer.getAdrPorts().get(1).getWidth(), adr2Offset);
					off = 1;					
				}
					
				tracerChecker[k][off+1] = new TracerChecker(dataBits, dataInvBits, memTracer.getDataPort().getWidth(), dataOffset);
				if (src){
					tracerChecker[k][off+2] = new TracerChecker(sourceBits, sourceInvBits, memTracer.getSourcePort().getWidth(), sourceOffset);
					off = off+3;
				} else {
					off = off+2;
				}				
				tracerChecker[k][off] = new TracerChecker(rwBits, rwInvBits, memTracer.getRwPort().getWidth(), rwOffset);				
			}
			
			if(t instanceof MessageTracerInstance){
				
				MessageTracer messageTracer = (MessageTracer) t.getDefinition();				
				List<Integer[]> msg1Bits = new ArrayList<Integer[]>();
				List<Integer[]> msg1InvBits = new ArrayList<Integer[]>();
				List<Integer[]> msg2Bits = new ArrayList<Integer[]>();
				List<Integer[]> msg2InvBits = new ArrayList<Integer[]>();
				List<Integer[]> msg3Bits = new ArrayList<Integer[]>();
				List<Integer[]> msg3InvBits = new ArrayList<Integer[]>();
				int msg1Offset = 0;
				int msg2Offset = 0;
				int msg3Offset = 0;
				boolean msg2 = false;
				boolean msg3 = false;
				
				if(messageTracer.getMsgPortCnt() == 1)
					if (messageTracer.getMsgPorts().get(0).getId() == 17){
						// shap threads
						msg1Offset = 0;
						Integer[] msg1Bits_i = new Integer[13];
						Integer[] msg1InvBits_i = new Integer[0];
						msg1Bits_i[0] = 0;
						msg1Bits_i[1] = 1;
						msg1Bits_i[2] = 2;
						msg1Bits_i[3] = 3;
						msg1Bits_i[4] = 4;
						msg1Bits_i[5] = 5;
						msg1Bits_i[6] = 6;
						msg1Bits_i[7] = 7;
						msg1Bits_i[8] = 8;
						msg1Bits_i[9] = 9;
						msg1Bits_i[10] = 10+i;
						msg1Bits_i[11] = 13;
						msg1Bits_i[12] = 14;
						msg1Bits.add(msg1Bits_i);
						msg1InvBits.add(msg1InvBits_i);
				}
				
				if(messageTracer.getMsgPortCnt() == 1)
					if (messageTracer.getMsgPorts().get(0).getId() == 18){
						// shap gc-ref
						msg1Offset = 0;
						Integer[] msg1Bits_i = new Integer[5];
						Integer[] msg1InvBits_i = new Integer[0];
						msg1Bits_i[0] = 10;
						msg1Bits_i[1] = 11;
						msg1Bits_i[2] = 20;
						msg1Bits_i[3] = 21;
						msg1Bits_i[4] = 22;
						msg1Bits.add(msg1Bits_i);
						msg1InvBits.add(msg1InvBits_i);
				}
				
				if(messageTracer.getMsgPortCnt() == 1)
					if (messageTracer.getMsgPorts().get(0).getId() == 19){
						// shap ref
						msg1Offset = 5;
						Integer[] msg1Bits_i = new Integer[9];
						Integer[] msg1InvBits_i = new Integer[0];
						msg1Bits_i[0] = 0;
						msg1Bits_i[1] = 1;
						msg1Bits_i[2] = 2;
						msg1Bits_i[3] = 3;
						msg1Bits_i[4] = 4;
						msg1Bits_i[5] = 5;
						msg1Bits_i[6] = 7;
						msg1Bits_i[7] = 8;
						msg1Bits_i[8] = 9;
						msg1Bits.add(msg1Bits_i);
						msg1InvBits.add(msg1InvBits_i);
				}
				
				if(messageTracer.getMsgPortCnt() == 3)
					if (messageTracer.getMsgPorts().get(0).getId() == 20 & messageTracer.getMsgPorts().get(1).getId() == 22 & messageTracer.getMsgPorts().get(2).getId() == 21){
						// shap baseaddr
						msg2 = true;
						msg3 = true;						
						
						msg1Offset = 0;
						msg2Offset = 0;
						msg3Offset = 0;
						Integer[] msg1Bits_i = new Integer[9];
						Integer[] msg1InvBits_i = new Integer[0];
						msg1Bits_i[0] = 0;
						msg1Bits_i[1] = 1;
						msg1Bits_i[2] = 2;
						msg1Bits_i[3] = 3;
						msg1Bits_i[4] = 4;
						msg1Bits_i[5] = 5;
						msg1Bits_i[6] = 7;
						msg1Bits_i[7] = 8;
						msg1Bits_i[8] = 9;
						msg1Bits.add(msg1Bits_i);
						msg1InvBits.add(msg1InvBits_i);
						
						Integer[] msg2Bits_i = new Integer[9];
						Integer[] msg2InvBits_i = new Integer[0];
						msg2Bits_i[0] = 0;
						msg2Bits_i[1] = 1;
						msg2Bits_i[2] = 2;
						msg2Bits_i[3] = 3;
						msg2Bits_i[4] = 4;
						msg2Bits_i[5] = 5;
						msg2Bits_i[6] = 7;
						msg2Bits_i[7] = 8;
						msg2Bits_i[8] = 9;
						msg2Bits.add(msg2Bits_i);
						msg2InvBits.add(msg2InvBits_i);
						
						Integer[] msg3Bits_i = new Integer[9];
						Integer[] msg3InvBits_i = new Integer[0];
						msg3Bits_i[0] = 0;
						msg3Bits_i[1] = 1;
						msg3Bits_i[2] = 2;
						msg3Bits_i[3] = 3;
						msg3Bits_i[4] = 4;
						msg3Bits_i[5] = 5;
						msg3Bits_i[6] = 7;
						msg3Bits_i[7] = 8;
						msg3Bits_i[8] = 9;
						msg3Bits.add(msg3Bits_i);
						msg3InvBits.add(msg3InvBits_i);
				}
				
				if(messageTracer.getMsgPortCnt() == 1)
					if (messageTracer.getMsgPorts().get(0).getId() == 23){
						// shap method
						msg1Offset = 0;
						Integer[] msg1Bits_i = new Integer[7];
						Integer[] msg1InvBits_i = new Integer[0];
						msg1Bits_i[0] = 0;
						msg1Bits_i[1] = 1;
						msg1Bits_i[2] = 2;
						msg1Bits_i[3] = 3;
						msg1Bits_i[4] = 4;
						msg1Bits_i[5] = 5;
						msg1Bits_i[6] = 6;
						msg1Bits.add(msg1Bits_i);
						msg1InvBits.add(msg1InvBits_i);
				}
				
				if(messageTracer.getMsgPortCnt() == 1)
					if (messageTracer.getMsgPorts().get(0).getId() == 24){
						// shap mc
						msg1Offset = 0;
						Integer[] msg1Bits_i = new Integer[7];
						Integer[] msg1InvBits_i = new Integer[0];
						msg1Bits_i[0] = 0;
						msg1Bits_i[1] = 1;
						msg1Bits_i[2] = 2;
						msg1Bits_i[3] = 3;
						msg1Bits_i[4] = 4;
						msg1Bits_i[5] = 5;
						msg1Bits_i[6] = 6+i;
						msg1Bits.add(msg1Bits_i);
						msg1InvBits.add(msg1InvBits_i);
				}
				
				if(messageTracer.getMsgPortCnt() == 1)
					if (messageTracer.getMsgPorts().get(0).getId() == 25){
						// shap mmu
						msg1Offset = 0;
						Integer[] msg1Bits_i = new Integer[5];
						Integer[] msg1InvBits_i = new Integer[0];
						msg1Bits_i[0] = 0;
						msg1Bits_i[1] = 1;
						msg1Bits_i[2] = 2;
						msg1Bits_i[3] = 3;
						msg1Bits_i[4] = 4;
						msg1Bits.add(msg1Bits_i);
						msg1InvBits.add(msg1InvBits_i);
				}
				
				if(messageTracer.getMsgPortCnt() == 1)
					if (messageTracer.getMsgPorts().get(0).getId() == 27){
						// internal tracer
						msg1Offset = 0;
						Integer[] msg1Bits_i = new Integer[1];
						Integer[] msg1InvBits_i = new Integer[0];
						msg1Bits_i[0] = 31;		
						msg1Bits.add(msg1Bits_i);
						msg1InvBits.add(msg1InvBits_i);
				}
				
				
				if (msg3)
					tracerChecker[k] = new TracerChecker[3];
				else
					if (msg2) 
						tracerChecker[k] = new TracerChecker[2];
					else
						tracerChecker[k] = new TracerChecker[1];
				
				
				tracerChecker[k][0] = new TracerChecker(msg1Bits, msg1InvBits, messageTracer.getMsgPorts().get(0).getWidth(), msg1Offset);
								
				if (msg2){
					tracerChecker[k][1] = new TracerChecker(msg2Bits, msg2InvBits, messageTracer.getMsgPorts().get(1).getWidth(), msg2Offset);
				}					
				if (msg3){
					tracerChecker[k][2] = new TracerChecker(msg3Bits, msg3InvBits, messageTracer.getMsgPorts().get(2).getWidth(), msg3Offset);
				}
					
				
			}
		}
		
	}
	
	public boolean doCycle(BitVector[][] values){
						
		boolean result = true;
				
		for (int i = 0; i<tracerChecker.length; i++){
			for(int j = 0; j<tracerChecker[i].length; j++){				
				result = result & tracerChecker[i][j].check(testVector1, values[i][j]);
			}
				
		}
		
		testVector1 = testVector1.increment();
		
		return result;
	}

	public boolean doEmptyCycle(){

		boolean result = true;
				
		for (int i = 0; i<tracerChecker.length; i++)
			for(int j = 0; j<tracerChecker[i].length; j++)
				result = result & tracerChecker[i][j].check(testVector1, null);
		
		testVector1 = testVector1.increment();
//		try {
//			System.out.println("Done Cycle "+testVector1.getBinaryString()+" "+testVector1.getLong());			
//		} catch (Exception e){
//			e.printStackTrace();
//		}
		
		
		return result;
	}
	
	public boolean doEmptyCycles(int cycles){
		
		
		boolean result = true;
		
		for(int i = 0; i<cycles; i++)
			result = result & doEmptyCycle();
		
		return result;
	}
	
	/**
	 * Checks transfered values for a tracer. Represent his predefined behavior.
	 * @author Stefan Alex
	 *
	 */
	class TracerChecker{
		
		private List<Integer[]> bits;
		private List<Integer[]> invBits;
		private int width;
		private int offset;
		
		/**
		 * The constructor.
		 * @param bits the stb-bits from the testvector.
		 * @param invBits the inverted stb-bits from the testvector.
		 * @param width the width of the tracer's input
		 * @param offset an offset for the testvector
		 */
		public TracerChecker(List<Integer[]> bits, List<Integer[]> invBits, int width, int offset){
			
			this.bits = bits;
			this.invBits = invBits;
			this.width = width;			
			this.offset = offset;
		}
		
		/**
		 * Check a testvector and it's result
		 * @param testVector the testvector
		 * @param stb <code>true</code>, if there where a strobe in the real tracer
		 * @param result the meseaured result
		 * @return <code>true</code>, if the result and stb matches the calculation.
		 */
		public boolean check(BitVector testVector, BitVector result){
			boolean calStb = false;
									
			for (int i = 0; i< bits.size(); i++){
				Integer bits_i[] = bits.get(i);
				Integer invBits_i[] = invBits.get(i);
				boolean calStb_i = true;
				for (int j = 0; j<bits_i.length; j++){					
					calStb_i = calStb_i & testVector.get(bits_i[j]);
				}
				for (int j = 0; j<invBits_i.length; j++){					
					calStb_i = calStb_i & !testVector.get(invBits_i[j]);
				}
				calStb = calStb | calStb_i;
			}
			
			
			if (calStb != (result != null)){
				System.out.println(testVector.getBinaryString());
				System.out.println("ERROR: "+calStb+" - "+(result != null)+" result1 "+testVector.getSubvector(offset, offset+width).getBinaryString()+" result2 "+result);
				try{
					System.out.println("Time: "+testVector.getSubvector(0, 31).getInt());	
				} catch (InvalidLengthException ile) {
					ile.printStackTrace();
				}
				
				System.out.println("");
				return false;
			}
				
			
			if (calStb){
				if (!testVector.getSubvector(offset, offset+width).equals(result)){
					System.out.println("ERROR: "+testVector.getSubvector(offset, offset+width).getBinaryString()+" - "+result.getBinaryString());
					try{
						System.out.println("Time: "+testVector.getSubvector(0, 31).getInt());	
					} catch (InvalidLengthException ile) {
						ile.printStackTrace();
					}
					System.out.println(testVector);
					System.out.println("");
					return false;
				}
					
			}
				
			if(calStb)
				System.out.println("Valid Action");
			//System.out.println("");
			return true;
			
			
		}
		
		
		
	}
	
}
