#lang racket

(provide
 current-i/o-mode
 bf)

; i/o modes:
; unicode - unicode character values
; numeric - decimal numbers
(define current-i/o-mode (make-parameter 'unicode))
       
; a brainf**k interpreter, given a bf program as a string

; bf commands:
; < move the tape pointer to the left
; > move the tape pointer to the right
; + increment the curent tape cell
; - decrement the current tape cell
; . output the current tape cell
; , input to the current tape cell
; [ if the current tape cell is 0, jump to the matching ]
; ] if the current tape cell is not 0, jump to the matching [
; # DEBUG: print the current contents of the tap
(define (bf in)
  ; special cdr and car that make infinite lists of 0s
  (define (cdr+ ls) (if (null? ls) ls (cdr ls)))
  (define (car+ ls) (if (null? ls) 0 (car ls)))
  
  ; step across the tape 
  (let step ([pc 0]            ; current instructions
             [tape-left '()]   ; values on the tape to the left
             [tape-cell 0]     ; current cell on the tape
             [tape-right '()]) ; values on the tape to the right
    
    ; only keep running so long as we have more program to run
    (when (< pc (string-length in))
      ; dispatch based on the current input
      (case (string-ref in pc)
        ; move the tape pointer to the left
        [(#\<)
         (step (+ pc 1)
               (cdr+ tape-left)
               (car+ tape-left)
               (cons tape-cell tape-right))]
        
        ; move the tape pointer to the right
        [(#\>)
         (step (+ pc 1)
               (cons tape-cell tape-left)
               (car+ tape-right)
               (cdr+ tape-right))]
        
        ; increment the current cell
        [(#\+)
         (step (+ pc 1)
               tape-left
               (+ tape-cell 1)
               tape-right)]

        ; decrement the current cell
        [(#\-)
         (step (+ pc 1)
               tape-left
               (- tape-cell 1)
               tape-right)]
        
        ; output the current cell
        [(#\.)
         (case (current-i/o-mode)
           [(numeric) (display tape-cell) (display " ")]
           [(unicode) (display (integer->char tape-cell))]
           [else (error 'bf (format "invalid i/o mode: ~s" (current-i/o-mode)))])
         
         (step (+ pc 1) tape-left tape-cell tape-right)]
        
        ; input into the current cell
        ; on eof, write 0
        [(#\,)
         (define cin
           (case (current-i/o-mode)
             [(numeric) (read)]
             [(unicode) (read-char)]
             [else (error 'bf (format "invalid i/o mode: ~s" (current-i/o-mode)))]))
         
         (step (+ pc 1) 
               tape-left
               (cond
                 [(eof-object? cin) 0]
                 [(eq? (current-i/o-mode) 'unicode) (char->integer cin)]
                 [else cin])
               tape-right)]
        
        ; jump past the matching ] if the cell under the pointer is 0
        [(#\[)
         (if (= tape-cell 0)
             ; find the matching ]
             (let bracket-loop ([pc (+ pc 1)] [stk 1])
               (case (string-ref in pc)
                 [(#\[) (bracket-loop (+ pc 1) (+ stk 1))]
                 [(#\])
                  (if (= stk 1)
                      (step (+ pc 1) tape-left tape-cell tape-right)
                      (bracket-loop (+ pc 1) (- stk 1)))]
                 [else
                  (bracket-loop (+ pc 1) stk)]))
             
             ; otherwise, just skip
             (step (+ pc 1) tape-left tape-cell tape-right))]
        
        ; jump back to the matching [ if the cell under the pointer is nonzero
        [(#\])
         (if (= tape-cell 0)
             ; just skip
             (step (+ pc 1) tape-left tape-cell tape-right)
             
             ; otherwise, find the matching ]
             (let bracket-loop ([pc (- pc 1)] [stk 1])
               (case (string-ref in pc)
                 [(#\]) (bracket-loop (- pc 1) (+ stk 1))]
                 [(#\[)
                  (if (= stk 1)
                      (step (+ pc 1) tape-left tape-cell tape-right)
                      (bracket-loop (- pc 1) (- stk 1)))]
                 [else
                  (bracket-loop (- pc 1) stk)])))]
        
        ; DEBUG: output the current values on the tape
        [(#\#)
         (printf "tape = ~a\n" 
                 (append (reverse tape-left) 
                         (list #\{ tape-cell #\})
                         tape-right))
         (step (+ pc 1) tape-left tape-cell tape-right)]
        
        ; everything else is a comment
        [else
         (step (+ pc 1) tape-left tape-cell tape-right)]))))

; a brainf**k interpreter, given a bf program as a string
(define (bf-old in)
  ; tape is a hash of index => integer
  (define mem (make-hash))
  
  ; step across the tape
  (let step ([pc 0]  ; program counter
             [tc 0]) ; tape counter
    
    ; get the current cell value and a helper to edit it
    (define cell (hash-ref mem tc 0))
    (define (store v) (hash-set! mem tc v))
             
    ; bail out at the end of the string
    (when (< pc (string-length in))
      (case (string-ref in pc)
        ; move the pointer to the right
        [(#\>) 
         (step (+ pc 1) (+ tc 1))]
        
        ; move the pointer to the left
        [(#\<) 
         (step (+ pc 1) (- tc 1))]
        
        ; increment the cell under the counter
        [(#\+)
         (store (+ cell 1))
         (step (+ pc 1) tc)]
        
        ; decrement the cell under the pointer
        [(#\-)
         (store (- cell 1))
         (step (+ pc 1) tc)]
        
        ; output the character signified by the cell at the pointer
        [(#\.)
         (display (integer->char cell))
         (step (+ pc 1) tc)]
        
        ; inputer a character and store it in the cell at the pointer
        [(#\,)
         (define cin (read-char))
         (if (eof-object? cin)
             ; exit on reading eof
             (step (string-length in) tc)
             
             ; otherwise, store it
             (begin
               (store (char->integer cin))
               (step (+ pc 1) tc)))]
        
        ; jump past the matching ] if the cell under the pointer is 0
        [(#\[)
         (if (= cell 0)
             ; find the matching ]
             (let bracket-loop ([pc (+ pc 1)] [stk 1])
               (case (string-ref in pc)
                 [(#\[) (bracket-loop (+ pc 1) (+ stk 1))]
                 [(#\])
                  (if (= stk 1)
                      (step (+ pc 1) tc)
                      (bracket-loop (+ pc 1) (- stk 1)))]
                 [else
                  (bracket-loop (+ pc 1) stk)]))
             
             ; otherwise, just skip
             (step (+ pc 1) tc))]
        
        ; jump back to the matching [ if the cell under the pointer is nonzero
        [(#\])
         (if (= cell 0)
             ; just skip
             (step (+ pc 1) tc)
             
             ; otherwise, find the matching ]
             (let bracket-loop ([pc (- pc 1)] [stk 1])
               (case (string-ref in pc)
                 [(#\]) (bracket-loop (- pc 1) (+ stk 1))]
                 [(#\[)
                  (if (= stk 1)
                      (step (+ pc 1) tc)
                      (bracket-loop (- pc 1) (- stk 1)))]
                 [else
                  (bracket-loop (- pc 1) stk)])))]
        
        ; otherwise, comment
        [else
         (step (+ pc 1) tc)]))))

; run bf files from the command line

; check for switches
; -n switch to numeric mode 
; -u switch to unicode mode (default)
(for ([f (in-vector (current-command-line-arguments))])
  (case f
    [("") (void)]
    [("-n") (current-i/o-mode 'numeric)]
    [("-u") (current-i/o-mode 'unicode)]
    [(file-exists? f)
     (printf "loading ~s\n" f)
     (bf (file->string f))]
    [else
     (printf "file does not exist: ~s\n" f)]))