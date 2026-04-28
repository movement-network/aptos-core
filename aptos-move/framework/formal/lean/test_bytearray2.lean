import Batteries

#print ByteArray.toList
#print ByteArray.append  
#print ByteArray.size
#print ByteArray.empty

-- Test what works
example : ByteArray.empty.data = #[] := rfl
example (ba : ByteArray) : ba.size = ba.data.size := rfl
