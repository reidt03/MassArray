convControl <- function (sequence, fragmentation, multiple=FALSE) {
	sequence <- toupper(sequence)
	N <- nchar(sequence)
	fragment.positions <- unlist(lapply(fragmentation, slot, "position"))
	fragment.ends <- fragment.positions + unlist(lapply(fragmentation, slot, "length")) - 1
	fragments <- gregexpr("G[ACT]*A[CT]*C[T]*T(?=G[CTG]*A)", sequence, perl=TRUE)[[1]]
	lengths <- regexpr("G[ACT]*A[CT]*C[T]*TG[CTG]*A", substr(rep(sequence, length(fragments)), fragments, rep(N, length(fragments))))
	attr(fragments, "match.length") <- attr(lengths, "match.length")
	if (all(unlist(fragments) == -1)) {
		warning("No conversion controls found")
		return(fragmentation)	
	}
	fragments.seq <- substr(rep(sequence, length(fragments)), fragments, fragments+attr(fragments, "match.length")-1)
	fragments.tg.position <- regexpr("TG", fragments.seq) + fragments
	peaks.unique <- unique(unlist(lapply(fragmentation, slot, "MW")))
	for (i in 1:length(fragments.seq)) {
		## DO NOT INCLUDE CG-CONTAINING FRAGMENTS AS CONVERSION CONTROLS
		if (length(grep("CG", fragments.seq[i])) > 0) next
		which.fragment <- which(fragment.positions <= fragments.tg.position[i] & fragment.ends >= fragments.tg.position[i])
		## DO NOT INCLUDE FRAGMENTS THAT ARE NOT ASSAYABLE
		if (!fragmentation[[which.fragment]]$assayable) next
		## EXCLUDE FRAGMENTS LOCATED WITHIN PRIMER SEQUENCES ON EITHER END
		## (NOT TRUE CONVERSION CONTROL BECAUSE BIASED IN FAVOR OF CONVERSION)
		if (fragmentation[[which.fragment]]$primer) next
		## DO NOT INCLUDE CONTROL FRAGMENTS THAT HAVE PEAK COLLISIONS
		if (any(fragmentation[[which.fragment]]$collisions > 0)) next
		## DO NOT INCLUDE CONTROL FRAGMENTS THAT WILL INTRODUCE PEAK COLLISIONS
		if (multiple) {
			sequence.plus.control <- gsub("CA", "CR", fragmentation[[which.fragment]]$sequence)
		}
		else {
			sequence.plus.control <- sub("CA", "CR", fragmentation[[which.fragment]]$sequence)
		}
		MW <- calcMW(sequence.plus.control)
		if (any(MW[2:length(MW)] %in% peaks.unique)) next
		num.collisions <- sum(unlist(lapply(findCollisions(peaks.unique), length)) - 1 ) / 2
		peaks.unique.plus.control <- unique(c(peaks.unique, MW))
		num.collisions.plus.control <- sum(unlist(lapply(findCollisions(peaks.unique.plus.control), length)) - 1) / 2
		if (num.collisions.plus.control > num.collisions) next
		## CONVERSION CONTROL IS GOOD => UPDATE FRAGMENTATION PROFILE APPROPRIATELY
		peaks.unique <- peaks.unique.plus.control
		fragmentation[[which.fragment]]$conversion.control <- TRUE
		fragmentation[[which.fragment]]$sequence <- sequence.plus.control
		fragmentation[[which.fragment]]$MW <- as.numeric(calcMW(fragmentation[[which.fragment]]$sequence))
		fragmentation[[which.fragment]]$CpGs <- as.integer(fragmentation[[which.fragment]]$CpGs + 1)
	}
	return(fragmentation)
}
