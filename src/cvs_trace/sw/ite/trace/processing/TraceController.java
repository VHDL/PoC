package ite.trace.processing;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.net.Socket;
import java.util.Iterator;

import ite.trace.processing.traceConfig.TraceConfig;
import ite.trace.processing.traceConfig.TriggerRegisterCompareType;
import ite.trace.types.CompressionType;
import ite.trace.types.TriggerMode;
import ite.trace.types.TriggerType;
import ite.trace.util.BitReader;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidConfigException;
import ite.trace.exceptions.InvalidLengthException;
import ite.trace.exceptions.InvalidMessageException;
import ite.trace.exceptions.InvalidTraceException;

/**
 * The main controller for trace-control and decompression.
 * 
 * @author stefan alex
 * 
 */
public class TraceController {

	private File lastTraceFile;

	private TraceConfig traceConfig;

	private byte[] config;

	private DataInputStream socketInputStream;

	private DataOutputStream socketOutputStream;
	
	private final int port = 8889;

	private static final int configLength = 2048;
	
	/**
	 * The Constructor.
	 * 
	 */
	public TraceController() {
	}

	/**
	 * Connect to FPGA board.
	 * 
	 * @throws InvalidConfigException
	 * @throws InvalidMessageException
	 * @throws IOException
	 */
	public void connect() throws InvalidConfigException,
			InvalidMessageException, IOException {
		if (connected())
			return;
		
		// initialize socket-connection		
		Socket s = new Socket("localhost", port);

		System.out.println("Created socket " + s.getLocalAddress()
				+ " on port " + s.getLocalPort());
		System.out.println("connected to " + s.getInetAddress() + " on port "
				+ s.getPort());

		socketInputStream = new DataInputStream(s.getInputStream());
		socketOutputStream = new DataOutputStream(s.getOutputStream());

		initialize();

		byte[] getConfigMessage = new byte[1];
		getConfigMessage[0] = 0;
		byte[] getConfigAnswer = sendAndReceive(getConfigMessage);
		
		config = new byte[configLength];
		System.arraycopy(getConfigAnswer, 0, config, 0, getConfigAnswer.length);

		traceConfig = new TraceConfig(toShortArray(config));
				
	}

	/**
	 * 
	 * @return <code>true</code>, if a connection to the board is
	 *         established.
	 */
	public boolean connected() {
		return traceConfig != null;
	}

	private short[] toShortArray(byte[] ba) {
		short[] sa = new short[ba.length];
		for (int i = 0; i < ba.length; i++) {
			short s = ba[i];
			if (s < 0)
				s = (short) (s & 0xFF);
			sa[i] = s;
		}

		return sa;
	}

	// ////////////////
	// Socket-Functions
	// ////////////////

	/**
	 * Sends a message and receives an answer
	 * 
	 * @param message
	 *            the coded message
	 * @return the answer
	 * @throws IOException
	 */
	private byte[] sendAndReceive(byte[] message) throws IOException {
	  socketOutputStream.writeByte(2);
	  socketOutputStream.writeInt(message.length+1);
	  // This length field is part of the transmitted message.
	  socketOutputStream.writeByte((byte)(message.length-1));
	  socketOutputStream.write(message);
	  socketOutputStream.flush();

	  int recvLength = socketInputStream.readInt();
	  byte[] recvMessage = new byte[recvLength];
	  socketInputStream.readFully(recvMessage);
	  return recvMessage;
	}

	/**
	 * Initialize communication backend.
	 * 
	 * @param filename
	 * @throws IOException
	 */
	private void initialize() throws IOException {
	  socketOutputStream.writeByte(0);
	  socketOutputStream.flush();

	  // get Ack
	  byte ack = socketInputStream.readByte();
	  if (ack != 0)	throw new IOException();
	}

	/**
	 * Initialize trace receiver. Set filename for trace storage.
	 * 
	 * @param filename
	 * @throws IllegalArgumentException
	 * @throws IOException
	 */
	private void initializeTraceReceiver(String filename, byte[] config)
			throws IllegalArgumentException, IOException {
	  socketOutputStream.writeByte(1);
	  socketOutputStream.writeUTF(filename);
	  socketOutputStream.writeInt(config.length);
	  socketOutputStream.write(config);
	  socketOutputStream.flush();

	  // get Ack
	  byte ack = socketInputStream.readByte();
	  if (ack != 0) throw new IOException();
	}

	/**
	 * Finish tracing. This means, close the file and free the memory.
	 * 
	 * @throws IOException
	 */
	private void finish() throws IOException {
		if (connected()){
		  socketOutputStream.writeByte(3);
		  socketOutputStream.flush();

		  // get Ack
		  byte ack = socketInputStream.readByte();
		  if (ack != 0)	throw new IOException();
		}		
	}

	/**
	 * Finish tracing. This means, close the file and free the memory, but don't
	 * cancel program.
	 * 
	 * @throws IOException
	 */
	private void flush() throws IOException {
	  socketOutputStream.writeByte(4);
	  socketOutputStream.flush();

	  // get Ack
	  byte ack = socketInputStream.readByte();
	  if (ack != 0)	throw new IOException();
	}

	//
	// get static informations about configuration
	//

	/**
	 * 
	 * @return the number of configured <code>Port</code>s.
	 */
	public int getPortCnt() {
		return traceConfig.getPortCnt();
	}

	/**
	 * Returns a iterator with all available id's. The elements are sorted.
	 * 
	 */
	public Iterator<Integer> getPortIds() {
		return traceConfig.getPortIds();
	}

	/**
	 * Returns the width of a given <code>Port</code>. If the port doesn't
	 * exists, <code>-1</code> is returned.
	 * 
	 * @param id
	 *            the <code>Port</code>s id
	 */
	public int getPortWidth(int id) {
		return traceConfig.getPortWidth(id);
	}

	/**
	 * Returns the inputs of a given port. If the port doesn't exists,
	 * <code>-1</code> is returned.
	 * 
	 * @param id
	 *            the <code>Port</code>s id
	 */
	public int getPortInputs(int id) {
		return traceConfig.getPortInputs(id);
	}

	/**
	 * Returns the compression-type of a given port. If the port doesn't exists,
	 * <code>null</code> is returned.
	 * 
	 * @param id
	 *            the <code>Port</code>s id
	 */
	public CompressionType getPortComp(int id) {
		return traceConfig.getPortComp(id);
	}

	/**
	 * 
	 * @return the number of configured <code>InstTracer</code>
	 */
	public int getInstTracerCnt() {
		return traceConfig.getInstTracerCnt();
	}

	/**
	 * Returns the number of instances of a given <code>InstTracer</code>. If
	 * the tracer doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>InstTracer</code>s id
	 */
	public int getInstTracerInstances(int i) {
		return traceConfig.getInstTracerInstances(i);
	}

	/**
	 * Returns the adress-port-id of a given <code>InstTracer</code>. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>InstTracer<code>s id
	 */
	public int getInstTracerAdrPort(int i) {
		return traceConfig.getInstTracerAdrPort(i);
	}

	/**
	 * Returns the branch-field of a given <code>InstTracer</code>. If the
	 * tracer doesn't exists, <code>false</code> is returned.
	 * 
	 * @param i
	 *            the <code>InstTracer</code>s id
	 */
	public boolean getInstTracerIsBranchInfo(int i) {
		return traceConfig.getInstTracerIsBranchInfo(i);
	}

	/**
	 * Returns the branch-port-id of a given <code>InstTracer</code>. If the
	 * tracer doesn't extsts, <code>null</code> is returned.
	 * 
	 * @param i
	 *            the <code>InstTracer</code>s id
	 */
	public int getInstTracerBranchPort(int i) {
		return traceConfig.getInstTracerBranchPort(i);
	}

	/**
	 * Returns the history-field of a given <code>InstTracer</code>. If the
	 * tracer doesn't exists, <code>false</code> is returned.
	 * 
	 * @param i
	 *            the <code>InstTracer</code>s id
	 */
	public boolean getInstTracerIsHistory(int i) {
		return traceConfig.getInstTracerIsHistory(i);
	}

	/**
	 * Returns the history-bytes of a given <code>InstTracer</code>. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>InstTracer</code>s id
	 */
	public int getInstTracerHistoryBytes(int i) {
		return traceConfig.getInstTracerHistoryBytes(i);
	}

	/**
	 * Returns the counter-bits of a given <code>InstTracer</code>. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>InstTracer</code>s id
	 */
	public int getInstTracerCounterBits(int i) {
		return traceConfig.getInstTracerCounterBits(i);
	}

	/**
	 * Returns the priority of a given <code>InstTracer</code>. If the tracer
	 * doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>InstTracer</code>s id
	 */
	public int getInstTracerPriority(int i) {
		return traceConfig.getInstTracerPriority(i);
	}

	/**
	 * 
	 * @return the number of configured <code>MessageTracer</code>.
	 */
	public int getMessageTracerCnt() {
		return traceConfig.getMessageTracerCnt();
	}

	/**
	 * Returns the instances of a given <code>MessageTracer</code>. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>MessageTracer</code>s id
	 */
	public int getMessageTracerInstances(int i) {
		return traceConfig.getMessageTracerInstances(i);
	}

	/**
	 * Returns the number of message-ports of a given <code>MessageTracer</code>.
	 * If the tracer doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>MessageTracer</code>s id
	 */
	public int getMessageTracerMsgPortCnt(int i) {
		return traceConfig.getMessageTracerMsgPortCnt(i);
	}

	/**
	 * Returns the id of message-ports of a given <code>MessageTracer</code>.
	 * If the tracer doesn't exists, <code>null</code> is returned.
	 * 
	 * @param i
	 *            the <code>MessageTracer</code>s id
	 */
	public Iterator<Integer> getMessageTracerMsgPorts(int i) {
		return traceConfig.getMessageTracerMsgPorts(i);
	}

	/**
	 * Returns the priority for a given <code>MessageTracer</code>. If the
	 * tracer doesn't exitsts, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>MessageTracer</code>s id
	 */
	public int getMessageTracerPriority(int i) {
		return traceConfig.getMessageTracerPriority(i);
	}

	/**
	 * 
	 * @return the number of configured <code>MemTracer</code>.
	 */
	public int getMemTracerCnt() {
		return traceConfig.getMemTracerCnt();
	}

	/**
	 * Returns the instances of a given <code>MemTracer</code>. If the tracer
	 * doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>MemTracer</code>s id
	 */
	public int getMemTracerInstances(int i) {
		return traceConfig.getMemTracerInstances(i);
	}

	/**
	 * Returns the number of adress-ports of a given <code>MemTracer</code>.
	 * If the tracer doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>MemTracer</code>s id
	 */
	public int getMemTracerAdrPortCnt(int i) {
		return traceConfig.getMemTracerAdrPortCnt(i);
	}

	/**
	 * Returns the adress-port-ids of a given <code>MemTracer</code>. If the
	 * tracer doesn't exists, <code>null</code> is returned.
	 * 
	 * @param i
	 *            the <code>MemTracer</code>s id
	 * 
	 */
	public Iterator<Integer> getMemTracerAdrPorts(int i) {
		return traceConfig.getMemTracerAdrPorts(i);
	}

	/**
	 * Returns the data-port-id of a given <code>MemTracer</code>. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>MemTracer</code>s id
	 */
	public int getMemTracerDataPort(int i) {
		return traceConfig.getMemTracerDataPort(i);
	}

	/**
	 * Returns the rw-port-id of a given <code>MemTracer</code>. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>MemTracer</code>s id
	 */
	public int getMemTracerRwPort(int i) {
		return traceConfig.getMemTracerRwPort(i);
	}

	/**
	 * Returns the source-port-id of a given <code>MemTracer</code>. If the
	 * tracer doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>MemTracer</code>s id
	 */
	public int getMemTracerSourcePort(int i) {
		return traceConfig.getMemTracerSourcePort(i);
	}

	/**
	 * Returns the collect-value-field of a given <code>MemTracer</code>. If
	 * the tracer doesn't exists, <code>false</code> is returned.
	 * 
	 * @param i
	 *            the <code>MemTracer</code>s id
	 */
	public boolean getMemTracerCollectVal(int i) {
		return traceConfig.getMemTracerCollectVal(i);
	}

	/**
	 * Returns the priority of a given <code>MemTracer</code>. If the tracer
	 * doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>MemTracer</code>s id
	 */
	public int getMemTracerPriority(int i) {
		return traceConfig.getMemTracerPriority(i);
	}

	/**
	 * 
	 * @return the number of configured <code>Statistic</code>.
	 */
	/*
	 * public int getStatisticCnt() { return traceConfig.getStatisticCnt(); }
	 */
	/**
	 * Returns the port of a given <code>Statistic</code>. If the tracer
	 * doesn't exists, <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the <code>Statistic</code>s id
	 */
	/*
	 * public int getStatisticPort(int i) { return
	 * traceConfig.getStatisticPort(i); }
	 */
	/**
	 * 
	 * @return the number of configured ice-register.
	 */
	public int getIceRegisterCnt() {
		return traceConfig.getIceRegisterCnt();
	}

	/**
	 * Returns the width of a given ice-register. If the register doesn't exists
	 * <code>-1</code> is returned.
	 * 
	 * @param i
	 *            the registers id
	 */
	public int getIceRegisterWidth(int i) {
		return traceConfig.getIceRegisterWidth(i);
	}

	/**
	 * @return <code>true</code>, if config is cycle-accurate
	 */
	public boolean isCycleAccurate() {
		return traceConfig.isCycleAccurate();
	}

	/**
	 * @return <code>true</code>, if config is in mode "inform about trigger"
	 */
	public boolean isInformTrigger() {
		return traceConfig.isInformTrigger();
	}

	/**
	 * 
	 * @return the number of bytes for counting cycle in a systems rum.
	 */
	public int getCycleCountBytes() {
		return traceConfig.getCycleCountBytes();
	}

	/**
	 * Returns the number of trigger-single-events.
	 */
	public int getTriggerSingleEventCnt() {
		return traceConfig.getTriggerSingleEventCnt();
	}

	/**
	 * 
	 * @return the single-event-ids.
	 */
	public int[] getTriggerSingleEventIds(){
		return traceConfig.getTriggerSingleEventIds();
	}
	
	/**
	 * 
	 * @param id
	 *            the trigger-single-event id
	 * @return the index (postion in array) of a given single-event
	 */
	public int getTriggerSingleEventIndex(int id) {
		return traceConfig.getTriggerSingleEventIndex(id);
	}
	
	/**
	 * 
	 * @param id the trigger-single-event id
	 * @return <code>true</code>if a single-event with a given id exists.
	 */
	public boolean containsTriggerSingleEvent(int id){
		return traceConfig.containsTriggerSingleEvent(id);
	}
	
	/**
	 * 
	 * @return the max width of all trigger-register
	 */
	public int getMaxTriggerRegisterWidth() {
		return traceConfig.getMaxTriggerRegisterWidth();
	}


	/**
	 * 
	 * @param id
	 *            the trigger-single-event id
	 * @return the registers width. If the parameter don't match,
	 *         <code>-1</code> is returned.
	 */
	public int getTriggerRegisterWidth(int id) {
		return traceConfig.getTriggerRegisterWidth(id);
	}
	
	/**
	 * 
	 * @param id
	 *            the trigger-single-event id
	 * @return the id of a <code>Port</code>, associated with a given
	 *         trigger-single-event. If the single-event doesn't exists, <code>-1</code> is
	 *         returned.
	 */
	public int getTriggerSingleEventPortId(int id) {
		return traceConfig.getTriggerSingleEventPortId(id);
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
		return traceConfig.getTriggerEventHasSecondRegister(id);
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
		return traceConfig.getTriggerRegisterValue(id, b);
	}

	/**
	 * @param id
	 *            the trigger-single-event id
	 * @return the compare-type of given register
	 */
	public TriggerRegisterCompareType getTriggerRegisterCompareType(int id) {
		return traceConfig.getTriggerRegisterCompareType(id);
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
		return traceConfig.setTriggerFirstRegisterValue(id, bv);
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
		return traceConfig.setTriggerSecondRegisterValue(id, bv);
	}
	
	/**
	 * 
	 * @return the number of trigger
	 */
	public int getTriggerCnt() {		
		return traceConfig.getTriggerCnt();
	}

	/**
	 * 
	 * @return the trigger-ids.
	 */
	public int[] getTriggerIds(){
		return traceConfig.getTriggerIds();
	}
	
	/**
	 * @param id the trigger id
	 * @return the trigger-index
	 */
	public int getTriggerIndex(int id){
		return traceConfig.getTriggerIndex(id);
	}
	
	/**
	 * 
	 * @param id the trigger id
	 * @return <code>true</code>if a trigger with a given id exists.
	 */
	public boolean containsTrigger(int id){
		return traceConfig.containsTrigger(id);
	}
	
	/**
	 * 
	 * @param id
	 *            the trigger-id
	 * @return the triggers mode
	 */
	public TriggerMode getTriggerMode(int id) {
		return traceConfig.getTriggerMode(id);
	}

	/**
	 * 
	 * @param id
	 *            the trigger-id
	 * @return the triggers type
	 */
	public TriggerType getTriggerType(int id) {
		return traceConfig.getTriggerType(id);
	}

	/**
	 * 
	 * @param id
	 *            the trigger-id
	 * @param eventNo the number of the input-event
	 * @return <code>true</code>, if the trigger is activ
	 */
	public boolean getTriggerActiv(int id, int eventNo) {
		return traceConfig.getTriggerActiv(id, eventNo);
	}
	
	/**
	 * 
	 * @param id
	 *            the trigger-id
	 * @return the associated events for a given trigger
	 */
	public int getTriggerEvents(int id){
		return traceConfig.getTriggerEvents(id);
	}
	
	// //////////////////////
	// Communication-Messages
	// //////////////////////

	/**
	 * Stops the cpu
	 * 
	 * @return <code>true</code> if succeded
	 */
	public boolean iceStopSystem() throws IOException {
		byte[] stopSystemMessage = new byte[1];
		stopSystemMessage[0] = 0x02;
		byte[] stopSystemAnswer = sendAndReceive(stopSystemMessage);

		return !(stopSystemAnswer[0] == 0);
	}

	/**
	 * 
	 * @return <code>true</code> if the trace-system is stopped, otherwise
	 *         <code>false</code>
	 */
	public boolean iceSystemStopped() throws InvalidMessageException,
			IOException {
		byte[] systemStoppedMessage = new byte[1];
		systemStoppedMessage[0] = 0x03;
		byte[] systemStoppedAnswer = sendAndReceive(systemStoppedMessage);

		return !(systemStoppedAnswer[0] == 0);
	}

	/**
	 * 
	 * Starts cpu
	 * 
	 * @return <code>true</code> if succeded
	 */
	public boolean iceStartSystem() throws InvalidMessageException, IOException {
		byte[] startSystemMessage = new byte[1];
		startSystemMessage[0] = 0x04;

		byte[] stopSystemAnswer = sendAndReceive(startSystemMessage);

		return !(stopSystemAnswer[0] == 0);
	}

	/**
	 * Return the value all given ice-register as <code>BitVector</code>.
	 * 
	 * @return the value as <code>BitVector</code>
	 */
	public BitVector getIceRegisterValues() throws InvalidMessageException,
			IOException {
		try {
			int width = traceConfig.getIceRegisterSumWidth();
			int neededBytes = (int) Math.ceil((double) width / 8.0);

			byte[] getIceRegisterValueMessage = new byte[1];
			getIceRegisterValueMessage[0] = 0x05;
			byte[] getIceRegisterValueAnswer = sendAndReceive(getIceRegisterValueMessage);

			if (getIceRegisterValueAnswer.length < neededBytes)
				throw new InvalidMessageException();

			BitVector result = new BitVector(width);
			for (int j = 0; j < neededBytes; j++) {
				result.setByte(j, getIceRegisterValueAnswer[j]);
			}
			return result;

		} catch (InvalidLengthException ile) {
			ile.printStackTrace();
			System.exit(-1);
		}
		return null;
	}

	/**
	 * Set an ice-register to a new value. If the <code>BitVector</code>
	 * doesn't match the registers length, a
	 * <code>IndexOutOfBoundsException</code> is thrown.
	 * 
	 * @param i
	 *            the register
	 * @param bv
	 *            the new value
	 * @return <code>true</code> if succeded
	 */
	public boolean setIceRegisterValue(int i, BitVector bv)
			throws InvalidMessageException, IOException {

		if (i + 1 > traceConfig.getIceRegisterCnt() | i < 0)
			return false;

		int neededBytes = (int) Math.ceil((double) traceConfig
				.getIceRegisterWidth(i) / 8.0);
		int maxBytes = (int) Math.ceil((double) traceConfig
				.getIceRegisterMaxWidth() / 8.0);

		byte[] setIceRegisterValueMessage = new byte[2 + maxBytes];
		setIceRegisterValueMessage[0] = 0x06;
		setIceRegisterValueMessage[1] = (byte) i;
		for (int j = 0; j < neededBytes; j++) {
			setIceRegisterValueMessage[2 + j] = bv.getByte(j);
		}
		for (int j = neededBytes; j < maxBytes; j++) {
			setIceRegisterValueMessage[2 + j] = 0;
		}
		byte[] setIceRegisterValueAnswer = sendAndReceive(setIceRegisterValueMessage);

		return !(setIceRegisterValueAnswer[0] == 0);
	}

	/**
	 * Set an trigger-register to a new value. If the <code>BitVector</code>
	 * doesn't match the registers-length, a
	 * <code>IndexOutOfBoundsException</code> is thrown.
	 * 
	 * @param id
	 *            the trigger-single-event id
	 * @param reg
	 *            <code>false</code> for the first register, <code>true</code>
	 *            for the second
	 * @param bv
	 *            the new value
	 * @return <code>true</code> if succeded
	 */
	public boolean setTriggerRegisterValue(int id, boolean reg, BitVector bv)
			throws InvalidMessageException, IOException {
		if(!reg){
			if(!traceConfig.setTriggerFirstRegisterValue(id, bv))
				return false;
		} else {
			if(!traceConfig.setTriggerSecondRegisterValue(id, bv))
				return false;
		}		
		
		int registerEventBits = Math.max(1, log2ceil(traceConfig.getTriggerSingleEventCnt()));
		int idExt;
		if (reg)
			idExt = traceConfig.getTriggerSingleEventIndex(id) | (1<<registerEventBits);
		else
			idExt = traceConfig.getTriggerSingleEventIndex(id) | (0<<registerEventBits);
		
		int neededBytes = (int) Math.ceil((double) traceConfig
				.getTriggerRegisterWidth(id) / 8.0);
		int maxBytes = (int) Math.ceil((double) traceConfig
				.getMaxTriggerRegisterWidth() / 8.0); 
			
		byte[] setTriggerRegisterValueMessage = new byte[2 + maxBytes];
		setTriggerRegisterValueMessage[0] = (byte) 0x07;
		setTriggerRegisterValueMessage[1] = (byte) idExt;
		for (int j = 0; j < neededBytes; j++) {
			setTriggerRegisterValueMessage[2+j] = bv.getByte(j);
		}
		for (int j = neededBytes; j < maxBytes; j++) {
			setTriggerRegisterValueMessage[2+j] = 0;
		}
		
		byte[] setTriggerRegisterValueAnswer = sendAndReceive(setTriggerRegisterValueMessage);

		return !(setTriggerRegisterValueAnswer[0] == 0);
	}

	/**
	 * Set the compare-type for register
	 * 
	 * @param id
	 *            the trigger-single-event id
	 * @param type
	 *            the new value
	 * @return <code>true</code> if succeded
	 */
	public boolean setTriggerRegisterCompareType(int id,
			TriggerRegisterCompareType type) throws InvalidMessageException,
			IOException {
		if(!traceConfig.setTriggerRegisterCompareType(id, type))
			return false;

		int singleEventIndex = getTriggerSingleEventIndex(id);
		
		byte[] setTriggerRegisterValueMessage = new byte[3];
		setTriggerRegisterValueMessage[0] = (byte) (0x08);
		setTriggerRegisterValueMessage[1] = (byte) singleEventIndex;
		setTriggerRegisterValueMessage[2] = (byte) type.getId();
		
		byte[] setTriggerRegisterValueAnswer = sendAndReceive(setTriggerRegisterValueMessage);

		return !(setTriggerRegisterValueAnswer[0] == 0);
	}

	/**
	 * Toogle the activ-field of a given trigger.
	 * 
	 * @param id
	 *            the trigger-id
	 * @param eventNo the number of the input-event
	 * @return <code>true</code> if succeded
	 */
	public boolean setTriggerActiv(int id, int eventNo)
			throws InvalidMessageException, IOException {
		if(!traceConfig.setTriggerActiv(id, eventNo))
			return false;
		
		// get trigger-index
		int triggerIndex = getTriggerIndex(id);
		
		byte[] setTriggerActivMessage = new byte[3];
		setTriggerActivMessage[0] = 0x09;
		setTriggerActivMessage[1] = (byte)triggerIndex;
		setTriggerActivMessage[2] = (byte)eventNo;
		
		byte[] setTriggerActivAnswer = sendAndReceive(setTriggerActivMessage);

		return !(setTriggerActivAnswer[0] == 0);
	}

	/**
	 * Set the mode of a given trigger.
	 * 
	 * @param id
	 *            the triggers id
	 * @param mode
	 *            the new mode
	 * @return <code>true</code> if succeded
	 */
	public boolean setTriggerMode(int id, TriggerMode mode)
			throws InvalidMessageException, IOException {
		if(!traceConfig.setTriggerMode(id, mode))
			return false;

		// get trigger-index
		int triggerIndex = getTriggerIndex(id);
		
		byte[] setTriggerModeMessage = new byte[3];
		setTriggerModeMessage[0] = (byte) 0x0A;
		setTriggerModeMessage[1] = (byte) triggerIndex;
		setTriggerModeMessage[2] = (byte) mode.getId();
		
		byte[] setTriggerModeAnswer = sendAndReceive(setTriggerModeMessage);

		return !(setTriggerModeAnswer[0] == 0);
	}

	/**
	 * Set the type of a given trigger.
	 * 
	 * @param trigId
	 *            the triggers id
	 * @param type
	 *            the new type
	 * @return <code>true</code> if succeded
	 */
	public boolean setTriggerType(int id, TriggerType type)
			throws InvalidMessageException, IOException {
		if(!traceConfig.setTriggerType(id, type))
			return false;

		// get trigger-index
		int triggerIndex = getTriggerIndex(id);
		
		byte[] setTriggerTypeMessage = new byte[3];
		setTriggerTypeMessage[0] = (byte) 0x0B;
		setTriggerTypeMessage[1] = (byte) triggerIndex;
		setTriggerTypeMessage[2] = (byte) type.getId();

		byte[] setTriggerTypeAnswer = sendAndReceive(setTriggerTypeMessage);

		return !(setTriggerTypeAnswer[0] == 0);
	}

	/**
	 * Start tracing and store data in a file.
	 * 
	 * @param f
	 * @return <code>true</code> if succeded.
	 * @throws InvalidMessageException
	 */
	public boolean startTracing(File f) throws InvalidMessageException,
			IOException {

		lastTraceFile = f;
		
		// fill config
		byte[] configExt = new byte[2048];
		System.arraycopy(config, 0, configExt, 0, config.length);

		initializeTraceReceiver(f.getAbsolutePath(), configExt);

		// start trace
		byte[] startTraceMessage = new byte[1];
		startTraceMessage[0] = (byte) (0x0C);

		byte[] startTraceAnswer = sendAndReceive(startTraceMessage);

		return !(startTraceAnswer[0] == 0);		
	}

	/**
	 * Stop tracing.
	 * 
	 * @return <code>true</code> if succeded.
	 * @throws InvalidMessageException
	 */
	public boolean stopTracing() throws InvalidMessageException, IOException {

		byte[] stopTraceMessage = new byte[1];
		stopTraceMessage[0] = (byte) (0x0D);

		byte[] stopTraceAnswer = sendAndReceive(stopTraceMessage);
		
		boolean success;
		if (stopTraceAnswer[0] == 0) {
			success = false;
		} else {
			success = true;
		}

		if (success) {
		  // wait a second before flushing, so that
		  // packets du not arrive after flush()
		  try{Thread.sleep(1000);}catch(Exception e){}
			flush();
		}

		return success;

	}

	/**
	 * Close program.
	 * 
	 */
	public void close() throws InvalidMessageException, IOException {
		finish();
	}

	// /////////////////
	// decompress trace
	// /////////////////

	/**
	 * Decompress the last trace, the trace-system captured.
	 */
	public boolean decompressLastTrace() throws FileNotFoundException,
			IOException, InvalidTraceException, InvalidLengthException,
			InvalidConfigException {

		if (lastTraceFile == null)
			return false;

		decompressTrace(lastTraceFile);
		return true;
	}

	/**
	 * Decompress a trace, captured in a given file.
	 * 
	 * @param f
	 * @throws FileNotFoundException
	 * @throws IOException
	 * @throws InvalidConfigException
	 * @throws InvalidTraceException
	 * @throws InvalidLengthException
	 */
	public void decompressTrace(File f) throws FileNotFoundException,
			IOException, InvalidConfigException, InvalidTraceException,
			InvalidLengthException {

		BitReader br = new BitReader(f);

		byte[] config = new byte[configLength];		
		for (int i = 0; i < configLength; i++) {
			config[i] = (byte) br.getBitsAsInt(8);
		}

		TraceConfig tr = new TraceConfig(toShortArray(config));

		// create csv-file
		File csvFile = new File(f.getName() + ".csv");
		tr.decompress(br, csvFile);

	}

	/**
	 * Creates an index for the filename.
	 * 
	 */
	private String incfilename(String filename) {
		char lastsymbol = filename.charAt(filename.length() - 1);

		String newfilename = "";

		if (('0' <= lastsymbol) & (lastsymbol <= '9')) {

			if (lastsymbol == '9') {
				newfilename = incfilename(filename.substring(0, filename
						.length() - 1));
				newfilename += '0';
			} else {

				newfilename = filename.substring(0, filename.length() - 1)
						+ (char) (lastsymbol + 1);
			}
		} else {
			newfilename = filename + "1";
		}

		return newfilename;
	}
	
	private int log2ceil(int value) {
		for (int i = 0; i < 31; i++) {
			if (pot2(i) >= value)
				return i;
		}
		return -1;
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
