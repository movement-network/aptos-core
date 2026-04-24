import Batteries

#check ByteArray.append
#check ByteArray.push
#check ByteArray.copySlice
#check @ByteArray.ext

-- Test if there's extensionality
example (ba1 ba2 : ByteArray) (h : ba1.data = ba2.data) : ba1 = ba2 := by
  cases ba1
  cases ba2
  simp [*]
