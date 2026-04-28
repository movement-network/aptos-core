import Batteries

#check ByteArray.size_toList
#check ByteArray.toList_data
#check List.toByteArray

-- Try simpler approach
example (ba : ByteArray) : ba.data.toList.length = ba.size := by
  simp [ByteArray.size]
