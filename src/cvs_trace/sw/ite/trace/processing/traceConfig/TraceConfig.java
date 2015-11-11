package ite.trace.processing.traceConfig;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.SortedSet;
import java.util.TreeSet;

import ite.trace.processing.traceConfig.decompress.DecompressCtrl;
import ite.trace.processing.traceConfig.tracer.InstTracer;
import ite.trace.processing.traceConfig.tracer.MemTracer;
import ite.trace.processing.traceConfig.tracer.MessageTracer;
import ite.trace.processing.traceConfig.tracer.Tracer;
import ite.trace.types.CompressionType;
import ite.trace.types.TriggerMode;
import ite.trace.types.TriggerOneRegisterCompareType;
import ite.trace.types.TriggerTwoRegistersCompareType;
import ite.trace.types.TriggerType;
import ite.trace.util.BitReader;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidConfigException;
import ite.trace.exceptions.InvalidLengthException;
import ite.trace.exceptions.InvalidTraceException;

/**
 * 
 * This class represents a trace-architecture, instantiated on the fpga-board.
 * @author Stefan Alex
 *
 */

public class TraceConfig {

	private ICE ice;

	private boolean cycleAccurate;

	private boolean informTrigger;

	private short timeBits;

	private final List<Port> ports;

	private final List<InstTracer> instTracer;

	private final List<MemTracer> memTracer;

	private final List<MessageTracer> messageTracer;

	private final List<Trigger> trigger;
	// don't change sorting of elements

	private final List<TriggerSingleEvent> triggerSingleEvents;
	// don't change sorting of elements

	private int cycleCountBytes;

	/**
	 * The Constructor.
	 * 
	 * @param config
	 *            the configuration-message, as it's received by the
	 *            fpga-tracing-system.
	 * @throws InvalidConfigException the given configuration doesn't match the definiton. See the exception for an error-code.
	 */
	public TraceConfig(short[] config) throws InvalidConfigException {
		super();

		ports = new LinkedList<Port>();
		instTracer = new LinkedList<InstTracer>();
		messageTracer = new LinkedList<MessageTracer>();
		memTracer = new LinkedList<MemTracer>();

		trigger = new LinkedList<Trigger>();
		triggerSingleEvents = new LinkedList<TriggerSingleEvent>();		

		try {

			if (config.length == 0)
				throw new InvalidConfigException(0);

			int messagePtr = 0;

			// 0. Ports
			{
				int portCnt = config[messagePtr];

				for (int i = 0; i < portCnt; i++) {

					if (config.length - (messagePtr + 1) < 3)
						throw new InvalidConfigException(0);

					short id = config[++messagePtr];
					short width = (short) (config[++messagePtr] + 1);
					
					short inputs = (short) (config[++messagePtr] & 0x3F);

					CompressionType comp = CompressionType.noneC;
					int compTemp = (config[messagePtr] & 0xC0) >> 6;
					switch (compTemp) {
					case 0: {
						comp = CompressionType.noneC;
						break;
					}
					case 1: {
						comp = CompressionType.diffC;
						break;
					}
					case 2: {
						comp = CompressionType.xorC;
						break;
					}
					case 3: {
						comp = CompressionType.trimC;
						break;
					}
					}

					ports.add(new Port(id, width, inputs, comp));
				}
			}

			// 1. Trigger
			{
				messagePtr++;
				if (messagePtr == config.length)
					throw new InvalidConfigException(1);

				// Trigger-Single-Events
				
				int triggerSingleEventCnt = config[messagePtr];

				for(int i = 0; i<triggerSingleEventCnt; i++){
					
					if (config.length - (messagePtr + 1) < 3)
						throw new InvalidConfigException(1);
					
					TriggerSingleEvent tse;
					int id = config[++messagePtr];
					
					int portNo = config[++messagePtr];
					Port port = getPort(portNo);
					if (port == null)
						throw new InvalidConfigException(-1);
					
					boolean twoRegs = (config[++messagePtr]&0x01)>0;
					int cmpInitInt = (config[messagePtr]&0x06)>>1;
					
					
					if (!twoRegs){
						
						TriggerOneRegisterCompareType cmpInit;
						
						switch(cmpInitInt){
						case 0:{
							cmpInit = TriggerOneRegisterCompareType.greaterThan;
							break;
						}
						case 1:{
							cmpInit = TriggerOneRegisterCompareType.equal;
							break;
						}
						case 2:{
							cmpInit = TriggerOneRegisterCompareType.smallerThan;
							break;
						}
						default:{
							throw new InvalidConfigException(1);
						}
						}
						
						tse = new TriggerEventOneRegister(id, getPort(portNo), cmpInit);
						
					}else{
						
						TriggerTwoRegistersCompareType cmpInit;
						
						switch(cmpInitInt){
						case 0:{
							cmpInit = TriggerTwoRegistersCompareType.betweenEqual;
							break;
						}
						case 1:{
							cmpInit = TriggerTwoRegistersCompareType.outside;
							break;
						}
						default:{
							throw new InvalidConfigException(1);
						}
						}
						
						tse = new TriggerEventTwoRegisters(id, getPort(portNo), cmpInit);
					}
					
					triggerSingleEvents.add(tse);
				}
			
				// get initial values
				
				int width = 0;
				for(TriggerSingleEvent tse : triggerSingleEvents){
					width += tse.getRegsWidths();
				}
				
				int cnt;
				
				if(width % 8 > 0)
					cnt = (width/8)+1;
				else
					cnt = width/8;
				
				if (config.length - (messagePtr + 1) < cnt)
					throw new InvalidConfigException(1);
				
				BitVector defaultRegValues = new BitVector(width);
				for(int i = 0; i<cnt; i++){
					defaultRegValues.setByte(i, (byte)config[++messagePtr]);
				}
				
				int index = 0;
				for(TriggerSingleEvent tse : triggerSingleEvents){
					tse.setRegValue(defaultRegValues.getSubvector(index, index+tse.getRegsWidths()));
					index += tse.getRegsWidths();
				}
								
//				// sort values
//				int size = triggerSingleEvents.size();
//				boolean change;
//				do{
//					change = false;
//					for(int i = 0; i<size-1; i++){
//						if(triggerSingleEvents.get(i).getId() > triggerSingleEvents.get(i+1).getId()){
//							triggerSingleEvents.add(i+1, triggerSingleEvents.remove(i));
//							change = true;
//						}
//					}
//					size = size-1;
//				} while(change);
				
				messagePtr++;
				if (messagePtr == config.length)
					throw new InvalidConfigException(1);

				// Trigger
				
				int triggerCnt = config[messagePtr];
				
				for(int i = 0; i<triggerCnt; i++){
					
					if (config.length - (messagePtr + 1) < 3)
						throw new InvalidConfigException(1);
					
					int id = config[++messagePtr];
					int events = config[++messagePtr];
					
					int typeInt = config[++messagePtr]&0x03;
					int modeInt = (config[messagePtr]&0x0C)>>2;
					TriggerMode mode;
					TriggerType type;					
					
					switch(modeInt){
					case 0:{
						mode = TriggerMode.pointTrigger;
						break;
					}
					case 1:{
						mode = TriggerMode.preTrigger;
						break;
					}
					case 2:{
						mode = TriggerMode.postTrigger;
						break;
					}
					case 3:{
						mode = TriggerMode.centerTrigger;
						break;
					}
					default:{
						throw new InvalidConfigException(1);
					}
					}
					
					switch(typeInt){
					case 0:{
						type = TriggerType.normal;
						break;
					}
					case 1:{
						type = TriggerType.start;
						break;
					}
					case 2:{
						type = TriggerType.stop;
						break;
					}
					default:{
						throw new InvalidConfigException(1);
					}
					}
					trigger.add(new Trigger(id, type, mode, events));
				
				}

			}

			// 2. InstTracer
			{
				messagePtr++;
				if (messagePtr == config.length)
					throw new InvalidConfigException(2);

				int instTracerCnt = config[messagePtr];

				for (int i = 0; i < instTracerCnt; i++) {

					if (config.length - (messagePtr + 1) < 3)
						throw new InvalidConfigException(2);

					Port adrPort = getPort(config[++messagePtr]);
					if (adrPort == null)
						throw new InvalidConfigException(-1);
					
					boolean branchInfo = (config[++messagePtr] & 0x80) > 0;
					short priority = (short) ((config[messagePtr] & 0x78)>>3);
					short historyBytes = (short) ((config[messagePtr] & 0x06)>> 1);
					boolean history = historyBytes > 0;
					boolean lsEncoder = (config[messagePtr] & 0x01) > 0;					
					short counterBytes = (short) config[++messagePtr];
										
					// other values
					Port branchPort = null;

					if (branchInfo) {
						messagePtr++;
						if (messagePtr == config.length)
							throw new InvalidConfigException(2);
						branchPort = getPort(config[messagePtr]);
					}

					InstTracer t = new InstTracer(adrPort, 
							branchPort, counterBytes, history, lsEncoder,
							historyBytes, priority, new LinkedList<Trigger>());

					instTracer.add(t);

				}
			}

			// 3. MemTracer
			{
				messagePtr++;
				if (messagePtr == config.length)
					throw new InvalidConfigException(4);

				int memTracerCnt = config[messagePtr];

				for (int i = 0; i < memTracerCnt; i++) {

					messagePtr++;
					if (messagePtr == config.length)
						throw new InvalidConfigException(4);
					short adrPortCnt = config[messagePtr];

					if (config.length - (messagePtr + 1) < 4 + adrPortCnt)
						throw new InvalidConfigException(4);

					List<Port> adrPorts = new ArrayList<Port>();

					for (int j = 0; j < adrPortCnt; j++) {
						adrPorts.add(getPort(config[++messagePtr]));

						if (adrPorts.get(j) == null)
							throw new InvalidConfigException(-1);
					}
					Port dataPort = getPort(config[++messagePtr]);
					if (dataPort == null)
						throw new InvalidConfigException(-1);

					Port rwPort = getPort(config[++messagePtr]);
					if (rwPort == null)
						throw new InvalidConfigException(-1);

					Port sourcePort;
					int sourcePortNo = config[++messagePtr];
					if(sourcePortNo == 0)
						sourcePort = null;
					else
						sourcePort = getPort(sourcePortNo);
					
					short priority = (short) (config[++messagePtr] & 0x0F);

					boolean collectVal = (config[messagePtr] & 0x10) > 0;

					MemTracer t = new MemTracer(adrPorts, dataPort, rwPort,
							sourcePort, collectVal, priority,
							new LinkedList<Trigger>());
					memTracer.add(t);

				}
			}

			// 4. MessageTracer
			{
				messagePtr++;
				if (messagePtr == config.length)
					throw new InvalidConfigException(3);

				int messageTracerCnt = config[messagePtr];
				
				// check for system-message-tracer (must be the last tracer in list)
				if(messageTracerCnt == 0)
					throw new InvalidConfigException(3);

				for (int i = 0; i < messageTracerCnt; i++) {
					
					messagePtr++;
					if (messagePtr == config.length)
						throw new InvalidConfigException(3);
					short msgPortCnt = config[messagePtr];

					if (config.length - (messagePtr + 1) < 1 + msgPortCnt)
						throw new InvalidConfigException(3);

					List<Port> msgPorts = new ArrayList<Port>();

					for (int j = 0; j < msgPortCnt; j++) {
						msgPorts.add(getPort(config[++messagePtr]));
						if (msgPorts.get(j) == null)
							throw new InvalidConfigException(-1);
					}

					short priority = config[++messagePtr];

					MessageTracer t = new MessageTracer(msgPorts, priority,
							new LinkedList<Trigger>());
					messageTracer.add(t);
				}
			}

			// 5. other informations

			if (config.length - (messagePtr + 1) < 1)
				throw new InvalidConfigException(11);

			timeBits = (short) (((config[++messagePtr] & 0xE0) >> 5) + 1);

			// boolean-values
			short booleanValues = config[messagePtr];

			cycleAccurate = (booleanValues & 0x01) > 0;
			informTrigger = (booleanValues & 0x02) > 0;

			// 6. Ice
			{
				messagePtr++;
				if (messagePtr == config.length)
					throw new InvalidConfigException(6);
				short iceRegCnt = config[messagePtr];

				if (config.length - (messagePtr + 1) < iceRegCnt)
					throw new InvalidConfigException(6);

				short[] iceRegs = new short[iceRegCnt];
				for (int i = 0; i < iceRegCnt; i++) {
					iceRegs[i] = config[++messagePtr];
				}

				ice = new ICE(iceRegs, new LinkedList<Trigger>());

			}

		} catch (InvalidLengthException ile) {
			ile.printStackTrace();
			System.exit(-1);
		}
	}

	/**
	 * 
	 * @return the number of configured <code>Port</code>s.
	 */
	public int getPortCnt() {
		return ports.size();
	}

	/**
	 * @return an iterator with all available id's. The elements are sorted.
	 * 
	 */
	public Iterator<Integer> getPortIds() {
		return getPortIds(ports);
	}

	/**
	 * @return an iterator with all available id's. The elements are sorted.
	 * 
	 */
	private Iterator<Integer> getPortIds(List<Port> portList) {
		SortedSet<Integer> s = new TreeSet<Integer>();
		for (Port p : portList)
			s.add((int) p.getId());
		return s.iterator();

	}

	/**
	 * 
	 * @return the port with the given id, or <code>null</code>.
	 */
	private Port getPort(int id) {
		for (Port p : ports)
			if (p.getId() == id)
				return p;
		return null;
	}
	
	/**
	 * 
	 * @param id
	 *            the port-id
	 * @return the width of a given port. If the port doesn't
	 * exists, <code>-1</code> is returned.
	 */
	public int getPortWidth(int id) {
		for (Port p : ports)
			if (p.getId() == id)
				return p.getWidth();

		return -1;
	}

	/**
	 * 
	 * 
	 * @param id
	 *            the port-id
	 * @return theinputs of a given port. If the port doesn't exists,
	 * <code>-1</code> is returned.
	 */
	public int getPortInputs(int id) {
		for (Port p : ports)
			if (p.getId() == id)
				return p.getInputs();

		return -1;
	}

	/**
	 * 
	 * @param id
	 *            the ports id
	 * @return the compression-type of a given port. If the port doesn't exists,
	 * <code>null</code> is returned.
	 */
	public CompressionType getPortComp(int id) {
		for (Port p : ports)
			if (p.getId() == id)
				return p.getComp();

		return null;
	}

	/**
	 * 
	 * @return the number of configured instruction-tracer.
	 */
	public int getInstTracerCnt() {
		return instTracer.size();
	}

	/**
	 * 
	 * 
	 * @param index
	 *            the instruction-tracer-index
	 * @return the number of instances of a given instrution-tracer. If
	 * the tracer doesn't exists, <code>-1</code> is returned.
	 */
	public int getInstTracerInstances(int index) {
		if (instTracer.size() < (index + 1) | index < 0)
			return -1;

		return instTracer.get(index).getAdrPort().getInputs();

	}

	/**
	 * @param index
	 *            the instruction-tracer-index
	 * @return the adress-port-id of a given instruction-tracer. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 */
	public int getInstTracerAdrPort(int index) {
		if (instTracer.size() < (index + 1) | index < 0)
			return -1;
		return instTracer.get(index).getAdrPort().getId();
	}

	/**
	 *  
	 * @param index
	 *            the instruction-tracer-index
	 * @return the branch-field of a given instruction-tracer. If the
	 * tracer doesn't exists, <code>false</code> is returned.
	 */
	public boolean getInstTracerIsBranchInfo(int index) {
		if (instTracer.size() < (index + 1) | index < 0)
			return false;
		return instTracer.get(index).isBranchInfo();
	}

	/**
	 * 
	 * @param index
	 *            the instruction-tracer-index
	 * @return the branch-port-id of a given instruction-tracer. If the
	 * tracer doesn't extsts, <code>null</code> is returned.
	 */
	public int getInstTracerBranchPort(int index) {
		if (instTracer.size() < (index + 1) | index < 0)
			return -1;
		Port p = instTracer.get(index).getBranchPort();
		if (p == null)
			return -1;
		return p.getId();
	}

	/**
	 * 
	 * @param index
	 *            the instruction-tracer-index
	 * @return the history-field of a given instruction-tracer. If the
	 * tracer doesn't exists, <code>false</code> is returned.
	 */
	public boolean getInstTracerIsHistory(int index) {
		if (instTracer.size() < (index + 1) | index < 0)
			return false;
		return instTracer.get(index).isHistory();
	}

	/**
	 * @param index
	 *            the instruction-tracer-index
	 * @return the number of history-bytes for a given instruction-tracer. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 */
	public int getInstTracerHistoryBytes(int index) {
		if (instTracer.size() < (index + 1) | index < 0)
			return -1;
		return instTracer.get(index).getHistoryBytes();
	}

	/**
	 * @param index
	 *            the instruction-tracer-index
	 * @return the number of counter-bits for a given instruction-tracer. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 */
	public int getInstTracerCounterBits(int index) {
		if (instTracer.size() < (index + 1) | index < 0)
			return -1;
		return instTracer.get(index).getCounterBits();
	}

	/**
	 * @param index
	 *            the instruction-tracer-index
	 * @return the priority of a given instruction-tracer. If the tracer
	 * doesn't exists, <code>-1</code> is returned.
	 * 
	 */
	public int getInstTracerPriority(int i) {
		if (instTracer.size() < (i + 1) | i < 0)
			return -1;
		return instTracer.get(i).getPriority();
	}

	/**
	 * 
	 * @return the number of configured message-tracer.
	 */
	public int getMessageTracerCnt() {
		return messageTracer.size();
	}

	/**
	 * @param index
	 *            the message-tracer-index
	 * @return the number of instances for a given message-tracer. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 */
	public int getMessageTracerInstances(int index) {
		if (messageTracer.size() < (index + 1) | index < 0)
			return -1;

		int minInput = Integer.MAX_VALUE;
		for (Port p : messageTracer.get(index).getMsgPorts()) {
			if (p.getInputs() < minInput)
				minInput = p.getInputs();
		}
		return minInput;
	}

	/**
	 * @param index
	 *            the message-tracer-index
	 * @return the number of adress-ports for a given message-tracer.
	 * If the tracer doesn't exists, <code>-1</code> is returned.
	 */
	public int getMessageTracerMsgPortCnt(int index) {
		if (messageTracer.size() < (index + 1) | index < 0)
			return -1;
		return messageTracer.get(index).getMsgPortCnt();
	}

	/**
	 * @param index
	 *            the message-tracer-index
	 * @return the id of message-ports of a given message-tracer. If
	 * the tracer doesn't exists, <code>null</code> is returned.
	 * 
	 */
	public Iterator<Integer> getMessageTracerMsgPorts(int index) {
		if (messageTracer.size() < (index + 1) | index < 0)
			return null;
		return getPortIds(messageTracer.get(index).getMsgPorts());
	}

	/**
	 * @param index
	 *            the message-tracer-index
	 * @return the priority of a given message-tracer. If the
	 * tracer doesn't exitsts, <code>-1</code> is returned.
	 */
	public int getMessageTracerPriority(int index) {
		if (messageTracer.size() < (index + 1) | index < 0)
			return -1;
		return messageTracer.get(index).getPriority();
	}

	/**
	 * 
	 * @return the number of configured memory-tracer.
	 */
	public int getMemTracerCnt() {
		return memTracer.size();
	}

	/**
	 * @param index
	 *            the memory-tracer-index
	 * @return the number of instances for a given memory-tracer. If the tracer
	 * doesn't exists, <code>-1</code> is returned.
	 */
	public int getMemTracerInstances(int index) {
		if (memTracer.size() < (index + 1) | index < 0)
			return -1;

		int minInput = Integer.MAX_VALUE;
		for (Port p : memTracer.get(index).getAdrPorts()) {
			if (p.getInputs() < minInput)
				minInput = p.getInputs();
		}
		if (memTracer.get(index).getDataPort().getInputs() < minInput)
			minInput = memTracer.get(index).getDataPort().getInputs();
		if (memTracer.get(index).getSourcePort().getInputs() < minInput)
			minInput = memTracer.get(index).getSourcePort().getInputs();
		return minInput;
	}

	/**
	 * @param index
	 *            the memory-tracer-index
	 * @return the number of adress-ports for a given memory-tracer. If
	 * the tracer doesn't exists, <code>-1</code> is returned.
	 */
	public int getMemTracerAdrPortCnt(int index) {
		if (memTracer.size() < (index + 1) | index < 0)
			return -1;
		return memTracer.get(index).getAdrPortCnt();
	}

	/**
	 * @param index
	 *            the memory-tracer-index
	 * @return the adress-port-ids of a given memory-tracer. If the
	 * tracer doesn't exists, <code>null</code> is returned.
	 */
	public Iterator<Integer> getMemTracerAdrPorts(int index) {
		if (memTracer.size() < (index + 1) | index < 0)
			return null;
		return getPortIds(memTracer.get(index).getAdrPorts());
	}

	/**
	 * @param index
	 *            the memory-tracer-index
	 * @return the data-port-id of a given memory-tracer. If the tracer
	 * doesn't exists, <code>-1</code> is returned.
	 */
	public int getMemTracerDataPort(int index) {
		if (memTracer.size() < (index + 1) | index < 0)
			return -1;
		return memTracer.get(index).getDataPort().getId();
	}

	/**
	 * 
	 * @param index
	 *            the memory-tracer-index
	 * @return the rw-port-id of a given memory-tracer. If the tracer
	 * doesn't exists, <code>-1</code> is returned.
	 * 
	 */
	public int getMemTracerRwPort(int index) {
		if (memTracer.size() < (index + 1) | index < 0)
			return -1;
		return memTracer.get(index).getRwPort().getId();
	}

	/**
	 * @param index
	 *            the memory-tracer-index
	 * Returns the source-port-id of a given memory-tracer. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 * 
	 */
	public int getMemTracerSourcePort(int index) {
		if (memTracer.size() < (index + 1) | index < 0)
			return -1;
		return memTracer.get(index).getSourcePort().getId();
	}

	/**
	 * @param index
	 *            the memory-tracer-index
	 * @return the collect-value-field of a given <code>MemTracer</code>. If the
	 * tracer doesn't exists, <code>false</code> is returned.
	 */
	public boolean getMemTracerCollectVal(int index) {
		if (memTracer.size() < (index + 1) | index < 0)
			return false;
		return memTracer.get(index).isCollectVal();
	}

	/**
	 * @param index
	 *            the memory-tracer-index
	 * @return the priority of a given memory-tracer. If the tracer
	 * doesn't exists, <code>-1</code> is returned.
	 */
	public int getMemTracerPriority(int i) {
		if (memTracer.size() < (i + 1) | i < 0)
			return -1;
		return memTracer.get(i).getPriority();
	}

	/**
	 * 
	 * @return the number of configured ice-register.
	 */
	public int getIceRegisterCnt() {
		return ice.getIceRegisterCnt();
	}

	/**
	 * 
	 * @param index
	 *            the ice-register-index
	 * @return the width of a given ice-register. If the register doesn't exists.
	 * <code>-1</code> is returned.
	 * 
	 */
	public int getIceRegisterWidth(int i) {
		return ice.getIceRegisterWidth(i);
	}

	/**
	 * @return the maximal width of an ice-register.
	 */
	public int getIceRegisterMaxWidth() {
		return ice.getIceRegisterMaxWidth();
	}

	/**
	 * Returns the width of all ice-register as sum.
	 * 
	 */
	public int getIceRegisterSumWidth() {
		return ice.getIceRegisterSumWidth();
	}

	/**
	 * @return <code>true</code>, if config is cycle-accurate.
	 */
	public boolean isCycleAccurate() {
		return cycleAccurate;
	}

	/**
	 * @return <code>true</code>, if config is in mode "inform about trigger".
	 */
	public boolean isInformTrigger() {
		return informTrigger;
	}

	/**
	 * 
	 * @return the number of bytes for counting cycle in a systems run.
	 */
	public int getCycleCountBytes() {
		return cycleCountBytes;
	}

	/**
	 * Returns the number of trigger-single-events.
	 */
	public int getTriggerSingleEventCnt() {
		return triggerSingleEvents.size();
	}

	/**
	 * 
	 * @return the single-event-ids.
	 */
	public int[] getTriggerSingleEventIds(){
		int result[] = new int[triggerSingleEvents.size()];
		for (int i = 0; i<triggerSingleEvents.size(); i++) {
			result[i] = triggerSingleEvents.get(i).getId();
		}
		return result;
	}
	
	
	/**
	 * 
	 * @param id
	 *            the single-event-id
	 * @return the id of a port, associated with a given
	 *         single-event. If the single-event doesn't exists, <code>-1</code> is
	 *         returned.
	 */
	public int getTriggerSingleEventPortId(int id) {
		for(TriggerSingleEvent tse : triggerSingleEvents)
			if(tse.getId()==id)
				return tse.getPort().getId();

		return -1;
	}
	
	
	/**
	 * 
	 * @param id
	 *            the single-event-id
	 * @return the index (postion in array) of a given single-event
	 */
	public int getTriggerSingleEventIndex(int id) {
		for(int i = 0; i<triggerSingleEvents.size(); i++)
			if (triggerSingleEvents.get(i).getId() == id)
				return i;
		return -1;
	}
	
	/**
	 * 
	 * @param id
	 *            the single-event-id
	 * @return <code>true</code>if a single-event with a given id exists.
	 */
	public boolean containsTriggerSingleEvent(int id){
		for(TriggerSingleEvent tse : triggerSingleEvents){
			if (tse.getId() == id)
				return true;
		}
		return false;
	}
	
	/**
	 * 
	 * @return the max width of all trigger-register.
	 */
	public int getMaxTriggerRegisterWidth() {
		int max = 0;
		for(TriggerSingleEvent tse : triggerSingleEvents){
			if (tse.getPort().getWidth() > max)
				max = tse.getPort().getWidth();
		}
		return max;
	}


	/**
	 * 
	 * @param id
	 *            the single-event-id
	 * @return the registers width. If the parameter don't match,
	 *         <code>-1</code> is returned.
	 */
	public int getTriggerRegisterWidth(int id) {
		for(TriggerSingleEvent tse : triggerSingleEvents)
			if(tse.getId()==id)
				return tse.getPort().getWidth();

		return -1;
	}

	/**
	 * 
	 * @param id
	 *            the trigger-single-events id
	 * @return the number of registers per event. <code>false</code> is
	 *         returned, if one register exists, <code>true</code> for two. If
	 *         the event doesn't exists, <code>false</code> is returned.
	 */
	public boolean getTriggerEventHasSecondRegister(int id) {
		for(TriggerSingleEvent tse : triggerSingleEvents)
			if(tse.getId()==id)
				return tse instanceof TriggerEventTwoRegisters;

		return false;
	}

	/**
	 * 
	 * @param id
	 *            the trigger-single-event id
	 * @param b
	 *            <code>true</code>, if the event contains two register,
	 *            otherwise <code>false</code>
	 * @return the register-value of a given event.
	 */
	public BitVector getTriggerRegisterValue(int id, boolean b) {
		for(TriggerSingleEvent tse : triggerSingleEvents)
			if(tse.getId()==id)
				if(!b)
					return tse.getReg1Value();
				else
					if (tse instanceof TriggerEventTwoRegisters)
						return ((TriggerEventTwoRegisters) tse).getReg2Value();
					else
						break;
		return null;
	}

	/**
	 * @param id
	 *            the trigger-single-event id
	 * @return the compare-type of given register
	 */
	public TriggerRegisterCompareType getTriggerRegisterCompareType(int id) {
		for(TriggerSingleEvent tse : triggerSingleEvents)
			if(tse.getId()==id)
				return tse.getRegisterCompareType();

		return null;
	}

	/**
	 * Set an trigger-register to a new value.
	 * @param id
	 *            the trigger-single-event id
	 * @param bv
	 *            the new value
	 * @return <code>true</code> if succeded
	 */
	public boolean setTriggerFirstRegisterValue(int id, BitVector bv){
		for(TriggerSingleEvent tse : triggerSingleEvents)
			if(tse.getId()==id){
				return tse.setReg1Value(bv);
			}
		return false;
	}
	

	/**
	 * Set an trigger-register to a new value. 
	 * 
	 * @param id
	 *            the trigger-single-event id
	 * @param bv
	 *            the new value
	 * @return <code>true</code> if succeded
	 */
	public boolean setTriggerSecondRegisterValue(int id, BitVector bv){
		for(TriggerSingleEvent tse : triggerSingleEvents)
			if(tse.getId()==id){
				if(tse instanceof TriggerEventTwoRegisters)
					return ((TriggerEventTwoRegisters)tse).setReg2Value(bv);
				
			}
		return false;

	}

	/**
	 * Sets the compare-type of the first trigger-register.
	 * @param id the trigger-single-event id
	 * @param type
	 * @return
	 */
	public boolean setTriggerRegisterCompareType(int id,
			TriggerRegisterCompareType type) {
		
		for(TriggerSingleEvent tse : triggerSingleEvents)
			if(tse.getId()==id){
				return tse.setRegisterCompareType(type);
			}
		return false;
	}
	
	/**
	 * 
	 * @return the number of trigger
	 */
	public int getTriggerCnt() {		
		return trigger.size();
	}

	/**
	 * 
	 * @return the triggert-ids.
	 */
	public int[] getTriggerIds(){
		int result[] = new int[trigger.size()];
		for (int i = 0; i<trigger.size(); i++) {
			result[i] = trigger.get(i).getId();
		}
		return result;
	}
	
	/**
	 * 
	 * @param id the trigger id
	 * @return <code>true</code>if a trigger with a given id exists.
	 */
	public boolean containsTrigger(int id){
		for(Trigger t : trigger)
			if(t.getId()==id)
				return true;
		return false;
	}

	/**
	 * 
	 * @param id
	 *            the trigger-id
	 * @return the triggers index
	 */
	public int getTriggerIndex(int id) {
		for(int i = 0; i<trigger.size(); i++)		
			if(trigger.get(i).getId()==id)
				return i;
		return -1;
	}
	
	/**
	 * 
	 * @param id
	 *            the trigger-id
	 * @return the triggers mode
	 */
	public TriggerMode getTriggerMode(int id) {
		for(Trigger t : trigger)
			if(t.getId()==id)
				return t.getMode();
		return null;
	}

	/**
	 * 
	 * @param id
	 *            the trigger-id
	 * @return the triggers type
	 */
	public TriggerType getTriggerType(int id) {
		for(Trigger t : trigger)
			if(t.getId()==id)
				return t.getType();
		return null;
	}

	/**
	 * 
	 * @param id
	 *            the trigger-id
	 * @param eventNo the number of the input-event
	 * @return <code>true</code>, if the trigger is activ
	 */
	public boolean getTriggerActiv(int id, int eventNo) {
		for(Trigger t : trigger)
			if(t.getId()==id)
				return t.getActiv(eventNo);
		return false;
	}

	/**
	 * Toogle the activ-field of a given trigger.
	 * 
	 * @param id
	 *            the single-event id
	 * @param eventNo the number of the input-event
	 * @return <code>true</code> if succeded
	 */
	public boolean setTriggerActiv(int id, int eventNo) {
		for(Trigger t : trigger)
			if(t.getId()==id){
				t.toogleActiv(eventNo);
				return true;
			}
		return false;
	}

	/**
	 * Set the mode of a given trigger.
	 * 
	 * @param id
	 *            the single-event id
	 * @param mode
	 *            the new mode
	 * @return <code>true</code> if succeded
	 */
	public boolean setTriggerMode(int id, TriggerMode mode) {
		for(Trigger t : trigger)
			if(t.getId()==id){
				t.setMode(mode);
				return true;
			}
		return false;
	}

	/**
	 * Set the type of a given trigger.
	 * 
	 * @param id
	 *            the single-event id
	 * @param type
	 *            the new type
	 * @return <code>true</code> if succeded
	 */
	public boolean setTriggerType(int id, TriggerType type) {
		for(Trigger t : trigger)
			if(t.getId()==id){
				t.setType(type);
				return true;
			}
		return false;
	}

	/**
	 * 
	 * @param id
	 *            the trigger-id
	 * @return the associated events for a given trigger
	 */
	public int getTriggerEvents(int id){
		for(Trigger t : trigger)
			if(t.getId()==id){
				return t.getEvents();
			}
		return -1;
	}
	
	/**
	 * Decompress a trace, given by the <code>BitReader</code> and the steam
	 * behind it, and write it to the csv-file
	 * 
	 * @param br
	 * @param outFile
	 * @throws IOException
	 * @throws InvalidTraceException
	 * @throws InvalidLengthException
	 */
	public void decompress(BitReader br, File outFile) throws IOException,
			InvalidTraceException, InvalidLengthException {

		List<Tracer> tracer = new ArrayList<Tracer>();
		tracer.addAll(instTracer);
		tracer.addAll(memTracer);
		tracer.addAll(messageTracer);

		DecompressCtrl.decompress(br, tracer, outFile, cycleAccurate, timeBits);
	}
}
