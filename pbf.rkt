#lang racket

(provide
 current-i/o-mode
 debug-ping
 pbf)

; debug mode for ping/pong
(define debug-ping (make-parameter #f))

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
; # DEBUG: print the current contents of the tape

; pbf commands:
; & spawn a new thread, set the current cell to 0 in the parent and 1 in the child
; ~ end the current thread
; ? wait for a ping on the channel number specified in the current tape cell
; ! send a ping on the channel specified in the current tape cell
(define (pbf in)
  ; special cdr and car that make infinite lists of 0s
  (define (cdr+ ls) (if (null? ls) ls (cdr ls)))
  (define (car+ ls) (if (null? ls) 0 (car ls)))
  
  ; only allow one thread to write at a time
  (define write-lock (make-semaphore 1))
  
  ; control communication on channels
  (define channels (make-hash))
  
  ; send a ping on a given channel
  (define (ping i)
    (hash-set! channels i #t)
    (when (debug-ping)
      (semaphore-wait write-lock)
      (printf "ping ~s\n" i)
      (semaphore-post write-lock)))
  
  ; wait for a ping on a given channel
  ; current a spinlock :(
  (define (pong i)
    (let loop ()
      (if (hash-ref channels i #f)
          (hash-remove! channels i) 
          (loop)))
    (when (debug-ping)
      (semaphore-wait write-lock)
      (printf "pong ~s\n" i)
      (semaphore-post write-lock)))
  
  ; loop across the tape 
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
         (semaphore-wait write-lock)
         (case (current-i/o-mode)
           [(numeric) (display tape-cell) (display " ")]
           [(unicode) (display (integer->char tape-cell))]
           [else (error 'bf (format "invalid i/o mode: ~s" (current-i/o-mode)))])
         (semaphore-post write-lock)
         
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
        
        ; spawn a new thread, set current cell to 0 in the parent and non-0 in the child
        [(#\&)
         ; spawn the child process
         (thread
          (lambda () (step (+ pc 1) tape-left 1 tape-right)))
         
         ; step the parent process
         (step (+ pc 1) tape-left 0 tape-right)]
        
        ; kill the current thread
        [(#\~)
         (void)]
        
        ; send a ping on a given channel
        [(#\!)
         (ping tape-cell)
         (step (+ pc 1) tape-left tape-cell tape-right)]
        
        ; receive a ping on a given channel
        [(#\?)
         (pong tape-cell)
         (step (+ pc 1) tape-left tape-cell tape-right)]
        
        ; DEBUG: output the current values on the tape
        [(#\#)
         (define (format-each each)
           (if (positive? each)
               (format "~a/~a" each (integer->char each))
               (format "~a" each)))
         
         (semaphore-wait write-lock)
         (printf "tape = ~a\n" 
                 (append (map format-each (reverse tape-left))
                         (list #\{ (format-each tape-cell) #\})
                         (map format-each tape-right)))
         (semaphore-post write-lock)
         (step (+ pc 1) tape-left tape-cell tape-right)]
        
        ; everything else is a comment
        [else
         (step (+ pc 1) tape-left tape-cell tape-right)]))))

; run pbf files from the command line

; check for switches
; -n switch to numeric mode 
; -u switch to unicode mode (default)
; -d toggle ping/pong debug mode (#f by default)
(for ([f (in-vector (current-command-line-arguments))])
  (case f
    [("") (void)]
    [("-n") (current-i/o-mode 'numeric)]
    [("-u") (current-i/o-mode 'unicode)]
    [("-d") (debug-ping (not (debug-ping)))]
    [(file-exists? f)
     (printf "loading ~s\n" f)
     (pbf (file->string f))]
    [else
     (printf "file does not exist: ~s\n" f)]))