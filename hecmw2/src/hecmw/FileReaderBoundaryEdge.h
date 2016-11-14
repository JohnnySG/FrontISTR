/*
 ----------------------------------------------------------
|
| Software Name :HEC-MW Ver 4.5 beta
|
|   ./src/FileReaderBoundaryEdge.h
|
|                     Written by T.Takeda,    2013/03/26
|                                Y.Sato,      2013/03/26
|                                K.Goto,      2010/01/12
|                                K.Matsubara, 2010/06/01
|
|   Contact address : IIS, The University of Tokyo CISS
|
 ----------------------------------------------------------
*/
#include "FileReader.h"
#include "FileReaderBinCheck.h"
namespace FileIO
{
#ifndef _FILEREADERBOUNDARYEDGE_H
#define	_FILEREADERBOUNDARYEDGE_H
class CFileReaderBoundaryEdge:public CFileReader
{
public:
    CFileReaderBoundaryEdge();
    virtual ~CFileReaderBoundaryEdge();
public:
    virtual bool Read(ifstream& ifs, string& sline);
    virtual bool Read_bin(ifstream& ifs);

    virtual string Name();
};
#endif	/* _FILEREADERBOUNDARYEDGE_H */
}