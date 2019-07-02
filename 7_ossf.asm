; Ochre Reversers for Elta Console
;
; Program: Oneshot Short
;
;   One-shot reverse delay, triggered by signal level with
;   feedback. Delay time ranges from a few samples to about 1/10th
;   second, with reverse playback times about half the delay time.
;
; Controls:
;
;   POT0: Delay    Time
;   POT1: Feedback Amount
;   POT2: Trigger  Threshold
;
; Description:
;
;   Listen to input signal, and when the level exceeds a trigger
;   threshold, set a recording target and record until it is reached.
;   When the recording target is reached, begin playing out the
;   delay line in reverse and wait for a new trigger.
;

; Memory
MEM	dline	$7fff		; delay line - use full memory

; Program modifiers
EQU	ingain	0.998		; input signal gain
EQU	cdgain	1.018		; cube distortion linearising gain
EQU	mindel	$000400		; minimum delay length
EQU	delscl	0.100	  	; mindel+declik+delscl*max(POT0) ~= $7fffff
EQU	hpcoef	0.20		; trigger level HPF coefficient
EQU	hpshlf	-1.0		; trigger level HPF shelf
EQU	rmscoef	0.06		; RMS average coefficient
EQU	rmsshlf	-1.0		; RMS shelf value
EQU	minsig	-0.0000001	; silence threshold
EQU	tscale	-0.40		; trigger threshold modifier
EQU	trgdel	$007000		; trigger delay time compensation

; Operational Constants
EQU	STEPF	$000100		; forward movement offset: +1 samples
EQU	STEPR	$000200		; reverse movement offset: +2 samples
EQU	SATPOS	$7fffff		; maximum positive saturated value
EQU	SATNEG	$800000		; minimum negative saturated value
EQU	ULTIMD	$7fff00		; ultimate sample delay address
EQU	PENULD	$7ffe00		; penultimate sample delay address
EQU	POTMSK	$7fc000		; 9 bit mask for exact pot comparison
EQU	CDMULT	-0.333333333333 ; cube distortion multiplier

; I/O ports
EQU	revout	DACL		; reverse output channel
EQU	fwdout	DACR		; forward output channel
EQU	sigl	ADCL		; signal input channel
EQU	trig	ADCR		; trigger input channel
EQU	delctl	POT0		; delay length control POT
EQU	ffbctl	POT1		; forward feedback control POT
EQU	thresh	POT2		; trigger threshold control POT

; Registers
EQU	temp	REG0		; temp register
EQU	ndel	REG1		; next delay length
EQU	ffb	REG2		; forward feedback signal
EQU	hpfil	REG3		; trigger HPF
EQU	fptr	REG4		; forward delay pointer
EQU	rptr	REG5		; reverse delay pointer
EQU	currr	REG6		; current reverse sample
EQU	curin	REG7		; current delay input sample
EQU	rmsfil	REG8		; rms average filter reg
EQU	target	REG9		; recording target
EQU	rwait	REG10		; record wait state
EQU	previn	REG11		; previous input sample
EQU	lspos	REG12		; last recording start point
EQU	ltrig	REG13		; previous trigger state
EQU	inlvl	REG14		; current input RMS level
EQU	npbe	REG15		; next playback end point
EQU	cpbe	REG16		; current playback end point
EQU	rfb	REG17		; reverse feedback signal

; Signature: EC-OSSF v1.00a (CC0)
	skp	0,start
	raw	$45432d4f
	raw	$53534620
	raw	$76312e30
	raw	$30612028
	raw	$43433029
start:

; Read delay time control and save
	or	mindel		; load minimum delay length
	rdax	delctl,delscl	; add scaled delay control
	wrax	ndel,0.0	; save to next delay length

; Read from current delay line output and save to feedback reg
	ldax	fptr		; load pointer to delay end
	wrax	ADDR_PTR,0.0	; save to read pointer
	rmpa	1.0		; read sample out of delay
	;wrax	fwdout,1.0	; DEBUG forward out
	mulx	ffbctl		; scale by forward feedback control

; Soft limit feedback signal
	wrax	temp,CDMULT	; scale feedback and store to temp reg
	mulx	temp		; (refer spin semi KB)
	;mulx	temp
	rdax	temp,1.0
	sof	CDGAIN,0.0	; recover cube distort gain
	wrax	ffb,0.0		; save to ffb and clear ACC

; Play out current reversed sample
	ldax	rptr		; load current play position
	skp	ZRO,playr	; if pointer is null, output silence
	wrax	ADDR_PTR,0.0	; else prepare read pointer
	rmpa	1.0		; fetch reverse sample
playr:	wrax	currr,1.0	; save current rev output
	wrax	revout,1.0	; output sample to reverse channel
	wrax	fwdout,1.0	; output sample to forward channel
	mulx	ffbctl		; scale by forward feedback control

; Soft limit feedback signal
	wrax	temp,CDMULT	; scale feedback and store to temp reg
	mulx	temp		; (refer spin semi KB)
	mulx	temp
	rdax	temp,1.0
	sof	CDGAIN,0.0	; recover cube distort gain
	wrax	rfb,0.0		; save to rfb and clear ACC

; Combine delay line inputs and feed into delay line
	ldax	rfb		; add reverse delay feedback
	rdax	sigl,ingain	; add scaled signal input
	wra	dline,1.0	; write input to delay
	wrax	curin,1.0	; save current input sample

; Examine input signal for trigger
	rdfx	hpfil,hpcoef	; high pass filter
	wrhx	hpfil,hpshlf
	wrax	temp,1.0	; save to temp for squaring
	mulx	temp		; square signal
	rdfx	rmsfil,rmscoef	; average
	wrlx	rmsfil,rmsshlf	; shelf lpf
	log	0.5,0.0		; take log, divide by two
	exp	1.0,0.0		; effective square root
	wrax	inlvl,0.0	; save current level
        ldax	thresh		; check for trigger disabled
	and	POTMSK
	skp	ZRO,tatrig	; threshold disabled, force trig
	ldax	inlvl		; re-load input level
	rdax	thresh,tscale	; load and subtract threshold
	skp	NEG,notrig	; if negative - below thresh
	ldax	ltrig		; examine trigger status
	skp	ZRO,tatrig	; on a positive transition
	skp	0,hasatg	; else not a positive transition
tatrig: ldax	target		; check current target
	skp	ZRO,armed	; if null, armed for next trigger
	skp	0,hasatg	; else not armed, but still triggered
armed:	ldax	ndel		; load the next delay length 
	wrax	npbe,1.0	; prepare next playback end point
	wrax	fptr,0.5	; save to forward ptr and halve
	wrax	target,0.0	; save to record target
hasatg:	sof	0.0,0.5		; set a positive flag in last trig
	skp	0,ntctd
notrig:	clr
ntctd:	wrax	ltrig,0.0	; save empty trigger for next iter

; Track input signal for ZRC and silence
	or	minsig		; load minimum amplitude thresh
	rdax	inlvl,1.0	; add the current signal RMS
	skp	GEZ,zrcchk	; if not silent, skip to ZRC check
	skp	0,zrcrst	; else skip to reset
zrcchk:	ldax	curin		; else:
	ldax	previn		; compare prevous and current sample
	skp	ZRC,zrcrst	; if zero crossing, skip to reset
	skp	0,zrcend	; else skip to pointer update
zrcrst:	clr
	wrax	lspos,0.0	; reset input pos
zrcend:	clr
	or	STEPF		; load the forward step offset
	rdax	lspos,1.0	; and increment for next iteration
	wrax	lspos,0.0	; save input pos
	ldax	curin		; load current input
	wrax	previn,0.0	; save to previous input

; Conditionally update reverse playback and check for reset
	ldax	rptr		; load reverse pointer
	skp	ZRO,nrpud	; if reverse pointer null, skip to end
	clr			; else
	or	STEPF		; load a forward step
	rdax	rptr,1.0	; add to reverse pointer
	xor	SATPOS		; compare with saturated limit
	skp	ZRO,lookbk	; if at end of delay, look backward
	xor	SATPOS		; else restore pointer
	skp	0,lookfw
lookbk:	or	PENULD		; point to one sample before end of delay
lookfw:	wrax	ADDR_PTR,0.0	; save pointer to next play sample

; Update reverse pointer to the next location
	or	STEPR		; load the reverse step
	rdax	rptr,1.0	; add to current reverse pointer
	wrax	rptr,0.0	; save reverse pointer

; Check for end of playback/reset
	or	trgdel		; load trigger compensation (>= 1)
	rdax	cpbe,1.0	; add current play target (& saturate)
	and	ULTIMD		; mask with top address
	rdax	rptr,-1.0	; subtract reverse pointer
	skp	GEZ,nrpud	; if not yet at end of play, skip to end
	clr			; else
	rmpa	1.0		; check next playback sample
	ldax	currr		; compare with current sample
	skp	ZRC,dorst	; if on a zero crossing, terminate play
	skp	0,nrpud		; else keep playing
dorst:	clr
	wrax	rptr,0.0	; reset play pointer
nrpud:	clr

; Update record wait pointer
	ldax	target
	skp	ZRO,nowait	; if target is null, skip over wait
	clr
	or	STEPF		; load forward step offset
	rdax	rwait,1.0	; increment record wait pointer
	wrax	rwait,1.0	; save wait pointer
	rdax	target,-1.0	; subtract current wait target
	skp	GEZ,recrst	; if at or beyond target, reset
	skp	0,nowait	; else not yet at target
recrst:	ldax	rptr		; load current play pointer
	skp	ZRO,dorrst	; if play pointer null, reset and start play
	skp	0,nowait	; else continue rec wait until pb ends
dorrst:	clr
	wrax	target,0.0	; reset target
	wrax	rwait,0.0	; reset wait pointer
	ldax	lspos		; load the new playpack start pos
	wrax	rptr,0.0	; initiate playback pointer and clear
	rdax	npbe,1.0	; load next playback target
	wrax	cpbe,0.0	; save to current playback target
nowait:	clr
