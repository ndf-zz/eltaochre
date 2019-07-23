; Ochre Reversers for Elta Console
;
; Program: Free-running Loop
;
;   Looping reverse delay with transitions across zero
;   crossings. Delay time ranges from approximately 0.01 seconds
;   to just under 1 second, with reverse playback times about
;   half the delay time. Modulation of delay time is staged
;   so changes only happen after each reverse playback is
;   finished.
;
; Controls:
;
;   POT0: Delay    Time
;   POT1: Feedback Amount
;   POT2: Mod      LFO|RND
;
; Description:
;
;   Scan the delay line in reverse, resetting the delay time
;   at the end of each scan. Delay time is modulated by an LFO
;   or a random value, scaled by POT2.
;

; Memory
MEM	dline	$7fff		; delay line - use full memory

; Program modifiers
EQU	ingain	0.998		; input signal gain
EQU	cdgain	1.018		; cube distortion linearising gain
EQU	mindel	$010000		; minimum delay length
EQU	delchk	$fffc00		; for minimum modulated delay check
EQU	delwal	$000400		; for minimum modulated delay check
EQU	delscl	0.99		; mindel+declik+potscl*max(POT0) ~= $7fffff
EQU	lfo1t	SIN0		; LFO1 source
EQU	lfo1f	3		; LFO1 rate
EQU	lfo1a	16387		; LFO1 amplitude
EQU	lfo2t	RMP0		; LFO2 source
EQU	lfo2f	12345		; LFO2 rate
EQU	lfo2a	4096		; LFO2 amplitude
EQU	tapmsk	$7DDB03		; LFSR taps

; Operational Constants
EQU	STEPF	$000100		; forward movement offset: +1 samples
EQU	STEPR	$000200		; reverse movement offset: +2 samples
EQU	SATPOS	$7fffff		; maximum positive saturated value
EQU	SATNEG	$800000		; minimum negative saturated value
EQU	ULTIMD	$7fff00		; ulitmate sample delay address
EQU	PENULD	$7ffe00		; penultimate sample delay address
EQU	POTMSK	$7fc000		; 9 bit pot mask
EQU	CDMULT	-0.333333333333	; cube distortion multiplier

; I/O ports
EQU	revout	DACL		; reverse output channel
EQU	fwdout	DACR		; forward output channel
EQU	sigl	ADCL		; signal input channel
EQU	modu	ADCR		; external modulation input
EQU	delctl	POT0		; delay length control POT
EQU	ffbctl	POT1		; forward feedback control POT
EQU	modctl	POT2		; delay modulation control POT

; Registers
EQU	temp	REG0		; temp register
EQU	lfsr	REG1		; noise source register
EQU	ndel	REG2		; next delay length
EQU	ffb	REG3		; forward feedback signal
EQU	rfb	REG4		; reverse feedback signal
EQU	fptr	REG5		; forward delay pointer
EQU	rptr	REG6		; reverse delay pointer
EQU	currr	REG7		; current reverse sample
EQU	ushot	REG8		; zero cross reset 'undershoot' error
EQU	oshot	REG9		; zero cross reset 'overshoot' error
EQU	lposc	REG10		; pointer to last positive-going zrc
EQU	lnegc	REG11		; pointer to last negative-going zrc
EQU	curin	REG12		; current delay input sample
EQU	previn	REG13		; previous delay input sample
EQU	lrtmp	REG15		; lfsr temp value (overlaps with temp)

; Signature: EC-FRLF v1.00b (CC0)
	skp	0,start
	raw	$45432d46
	raw	$524c4620
	raw	$76312e30
	raw	$30622028
	raw	$43433029

; Initialisation
start:	skp	RUN,main
	or	$000001
	rdax	modctl,1.0	; seed LFSR with modulation POT value
	wrax	lfsr,0.0
	wlds	lfo1t,lfo1f,lfo1a
	wldr	lfo2t,lfo2f,lfo2a

; Read delay time control and save
main:	or	mindel		; load minimum delay length
	rdax	delctl,delscl	; add scaled delay control
	wrax	ndel,0.0	; save to next delay length

; Output current reverse sample
	ldax	rptr		; load current play position
	wrax	ADDR_PTR,0.0	; prepare read pointer
	rmpa	1.0		; fetch reverse sample
	wrax	currr,1.0	; save current rev output
	wrax	revout,1.0	; output to reverse channel
	wrax	fwdout,1.0	; output to forward channel
	mulx	ffbctl		; scale by reverse feedback control POT

; Soft limit feedback signal
	wrax	temp,CDMULT	; scale feedback and store to temp reg
	mulx	temp
	mulx	temp
	rdax	temp,1.0	; soft limit feedback ref: spin kb
	sof	CDGAIN,0.0
	wrax	rfb,0.0		; save to reverse fb reg and clear ACC

; Combine delay line inputs and feed into delay line
	ldax	rfb		; add reverse delay signal
	rdax	sigl,ingain	; add scaled signal input
	wra	dline,1.0	; write input to delay
	wrax	curin,1.0	; save input value for ZRC

; Track signal going into delay for zero crossings
	ldax	previn		; read last input sample
	skp	ZRC,zrcin	; if zero crossing, check polarity
	skp	0,zrcend	; else skip to updating existing pointers
zrcin:	skp	NEG,zrcpos	; this is a positive-going crossing
zrcneg:	clr			; else negative-going zero crossing
	wrax	lnegc,0.0	; reset the negative ZRC pointer
	skp	0,zrcend
zrcpos:	clr
	wrax	lposc,0.0	; reset the positive-going ZRC pointer

; Adjust zrc pointers
zrcend:	clr
	or	STEPF		; load the forward step offset
	rdax	lposc,1.0	; add the last positive ZRC pointer
	wrax	lposc,0.0	; save and clear ACC
	or	STEPF		; load the forward step offset
	rdax	lnegc,1.0	; add the last negative ZRC pointer
	wrax	lnegc,0.0	; save and clear ACC

; Save the current delay input in a reg for next comparison
	ldax	curin		; re-fetch the current delay input
	wrax	previn,0.0	; save and zero ACC

; Load a pointer to the next reverse sample, and check for end of delay
	or	STEPF		; load the address increment into ACC
	rdax	rptr,1.0	; look ahead to the next reverse sample
	xor	SATPOS		; compare with limit value
	skp	ZRO,lookbk	; if at end of delay, look back
        xor	SATPOS		; restore look forward addr
	skp	0,lookfw
lookbk:	or	PENULD		; look one sample back instead of forward
lookfw:	wrax	ADDR_PTR,0.0	; prepare read pointer to next rev sample

; Update reverse pointer for next sample
	or	STEPR		; load the reverse increment into ACC
	rdax	rptr,1.0	; add to the current reverse ptr
	wrax	rptr,0.0	; save updated position and clear ACC

; Check if reverse pointer needs to be reset
	rdax	oshot,1.0	; add previous reset's overshoot
	rdax	ushot,-1.0	; subtract current reset undershoot
	rdax	fptr,-1.0	; subtract forward delay length
	xor	SATNEG		; check against the bottom rail
	skp	ZRO,fixrst	; the comparison would never work, fix it
	xor	SATNEG		; restore computed value
fixrst: rdax	rptr,1.0	; add current reverse ptr
	wrax	temp,1.0	; save delay time overshoot in case of reset
	skp	NEG,norst	; if not yet in declick window, move on
	clr
	rmpa	1.0		; load _next_ reverse sample
	ldax	currr		; load current reverse sample
	skp	ZRC,dozrc	; perform reset on zero crossing
	skp	0,norst		; else skip reset
dozrc:	skp	NEG,dzneg	; this is a positive-going crossing
	ldax	lposc		; load the positive-going input
	skp	0,dorst
dzneg:	ldax	lnegc		; load the negative-going input
dorst:	wrax	ushot,1.0	; save to the reset undershoot record
	wrax	rptr,0.0	; perform reset of reverse pointer
	rdax	temp,0.5	; load previous overshoot and halve
	wrax	oshot,0.0	; save this reset's overshoot error

; Compute a delay time modulation and update next delay target
	sof	0.0,0.45	; load offset
	rdax	modctl,-0.9	; subtract modulation control
	and	$ff8000		; mask lower bits
	skp	GEZ,dolfo	; if positive: LFO, otherwise RND
	wrax	temp,0.0	; save and clear
	rdax	lfsr,0.5	; shift lfsr one bit right
	wrax	lrtmp,0.0	; save and clear
	ldax	lfsr		; re-load original value
	and	$000001		; fetch LSB
	skp	ZRO,nomsk	; if clear, don't XOR
	ldax	lrtmp		; re-load shifted value
	xor	tapmsk		; toggle feedback bits
	skp	0,lfwr
nomsk:	ldax	lrtmp		; re-load shifted value
lfwr:	wrax	lfsr,1.0	; save to shift reg
	sof	1.0,-0.5	; convert to bi-polar
	mulx	temp		; scale by pot value
	skp	0,domod
dolfo:	wrax	temp,0.0	; save amplification and clear
	cho	rdal,lfo1t	; read LFO
	mulx	temp		; and scale
domod:	rdax	ndel,1.0	; add mod to next delay time
	wrax	fptr,0.0	; save and clear acc
	or	delchk		; load negative worst case del
	rdax	fptr,1.0	; add current delay time
	skp	GEZ,norst	; this delay time is ok
	clr
	or	delwal		; otherwise load the worst minimum
	wrax	fptr,0.0
norst:	clr
